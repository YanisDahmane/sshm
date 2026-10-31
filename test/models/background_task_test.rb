require "test_helper"

class BackgroundTaskTest < ActiveSupport::TestCase
  def enqueue(servers = [ servers(:web), servers(:db) ], **options, &block)
    BackgroundTask.enqueue!(kind: "inventory", label: "Inventaire", servers: servers, user: users(:one), **options, &block)
  end

  test "enqueue! creates a queued item per server and yields them" do
    yielded = []
    task = enqueue { |item| yielded << item.server_name }

    assert_equal "queued", task.status
    assert_equal %w[Database Web], task.items.map(&:server_name)
    assert_equal %w[Database Web], yielded
    assert_equal({ done: 0, total: 2, failed: 0 }, task.progress)
  end

  test "the status follows the items" do
    task = enqueue
    db, web = task.items.to_a

    db.start!
    assert_equal "running", task.reload.status
    assert task.started_at

    db.finish!(:succeeded)
    assert_equal "running", task.reload.status
    assert_nil task.finished_at

    web.start!
    web.finish!(:failed, "Clé refusée")
    task.reload
    assert_equal "partial", task.status
    assert task.finished_at
    assert_equal({ done: 2, total: 2, failed: 1 }, task.progress)
  end

  test "every item succeeded or failed" do
    task = enqueue
    task.items.each { |item| item.finish!(:succeeded) }
    assert_equal "succeeded", task.reload.status

    task = enqueue
    task.items.each { |item| item.finish!(:failed) }
    assert_equal "failed", task.reload.status
  end

  test "a task without items is queued, then done once started" do
    task = enqueue([])
    assert_equal "queued", task.status

    task.start!
    task.refresh!(result: "Rien à faire")
    assert_equal [ "succeeded", "Rien à faire" ], [ task.status, task.result ]
  end

  test "fail! interrupts the unfinished items" do
    task = enqueue
    db, web = task.items.to_a
    db.finish!(:succeeded)

    task.fail!("Erreur interne (RuntimeError)")

    assert_equal [ "failed", "Erreur interne (RuntimeError)" ], [ task.reload.status, task.result ]
    assert_equal [ "succeeded", "failed" ], [ db.reload.status, web.reload.status ]
    assert_equal "Interrompu", web.message
  end

  test "filters, labels and author" do
    queued = enqueue
    failed = enqueue.tap { |task| task.fail!("x") }
    partial = enqueue.tap { |task| task.items.first.finish!(:failed) && task.items.last.finish!(:succeeded) }

    assert_equal [ queued ], BackgroundTask.filtered("queued").to_a
    assert_equal [ failed, partial ].sort_by(&:id), BackgroundTask.filtered("failed").order(:id).to_a
    assert_equal 3, BackgroundTask.filtered("nope").count
    assert_equal [ queued ], BackgroundTask.unfinished.to_a
    assert_equal "Inventaire", queued.kind_label
    assert_equal "yanis@test.fr", BackgroundTask.new(user: User.new(email: "yanis@test.fr")).author_name
    assert_equal "Système", BackgroundTask.new.author_name
  end

  test "validations" do
    task = BackgroundTask.new(kind: "nope", status: "nope", label: "")
    assert_not task.valid?
    assert_equal %i[kind status label], task.errors.attribute_names
  end

  test "expired: finished tasks older than 30 days" do
    old = enqueue.tap { |task| task.fail!("x") && task.update_columns(created_at: 31.days.ago) }
    old_unfinished = enqueue.tap { |task| task.update_columns(created_at: 31.days.ago) }
    enqueue.tap { |task| task.fail!("x") }

    assert_equal [ old ], BackgroundTask.expired.to_a
    PurgeBackgroundTasksJob.perform_now
    assert_not BackgroundTask.exists?(old.id)
    assert BackgroundTask.exists?(old_unfinished.id)
    assert_equal 0, BackgroundTaskItem.where(background_task_id: old.id).count
  end

  test "deleting a server fails its waiting items and keeps its name" do
    task = enqueue
    servers(:web).destroy!

    item = task.items.reload.find_by!(server_name: "Web")
    assert_nil item.server_id
    assert_equal [ "failed", "Serveur supprimé" ], [ item.status, item.message ]
  end

  test "a deleted user leaves the task to the system" do
    task = enqueue
    BackgroundTask.where(id: task.id).update_all(user_id: users(:viewer).id)
    users(:viewer).delete
    assert_equal "Système", task.reload.author_name
  end

  test "the purge runs every day in development and production" do
    recurring = YAML.load_file(Rails.root.join("config/recurring.yml"), aliases: true)
    %w[development production].each do |environment|
      assert_equal "PurgeBackgroundTasksJob", recurring.dig(environment, "purge_background_tasks", "class")
    end
  end
end
