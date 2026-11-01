require "test_helper"

class StaleTasksTest < ActiveSupport::TestCase
  include StubHelpers
  include ActiveJob::TestHelper

  def per_server_task(created_at: 4.hours.ago)
    BackgroundTask.enqueue!(kind: "inventory", label: "Inventaire", servers: [ servers(:web), servers(:db) ], user: nil) do |item|
      Inventory::CollectJob.perform_later(item.server, task_item: item)
    end.tap { |task| task.update_columns(created_at: created_at) }
  end

  def sweep(live: [])
    stub_method(StaleTasks, :live_job_ids, live) { StaleTasks.call }
  end

  test "a task item or an automation task remembers the id of its job" do
    task = per_server_task
    assert task.items.all? { |item| item.active_job_id.present? }
    assert_equal enqueued_jobs.map { |job| job["job_id"] }.sort, task.items.map(&:active_job_id).sort

    automation = Automation.all_kinds.find { |candidate| candidate.kind == "keys_scan" }
    automation_task = automation.enqueue!(user: nil, tracked: true)
    assert_equal enqueued_jobs.last["job_id"], automation_task.reload.active_job_id
  end

  test "items whose job no longer exists fail, then the task's status is computed again" do
    task = per_server_task
    alive, gone = task.items.order(:id).to_a

    assert_equal 1, sweep(live: [ alive.active_job_id ])
    assert_equal "queued", alive.reload.status
    assert_equal [ "failed", "Interrompue : le job n'existe plus" ], [ gone.reload.status, gone.message ]
    assert_equal "running", task.reload.status # one item done (failed), one still waiting

    alive.update!(status: "succeeded", finished_at: Time.current)
    task.refresh!
    assert_equal "partial", task.status
  end

  test "a task whose jobs all still exist, or a recent one, is never touched" do
    task = per_server_task
    recent = per_server_task(created_at: 2.hours.ago)

    assert_equal 0, sweep(live: task.items.map(&:active_job_id))
    assert_equal 0, sweep(live: task.items.map(&:active_job_id))
    assert task.items.reload.all? { |item| item.status == "queued" }
    assert recent.items.reload.all? { |item| item.status == "queued" }
  end

  test "a task run by one job fails as a whole when its job is gone" do
    automation = Automation.all_kinds.find { |candidate| candidate.kind == "keys_scan" }
    task = automation.enqueue!(user: nil, tracked: true)
    task.update_columns(created_at: 4.hours.ago)

    assert_equal 0, sweep(live: [ task.active_job_id ])
    assert_equal "queued", task.reload.status

    assert_equal 1, sweep
    assert_equal [ "failed", "Interrompue : le job n'existe plus" ], [ task.reload.status, task.result ]
    assert_not_nil task.finished_at
  end

  test "a finished task is left alone" do
    task = per_server_task
    task.items.update_all(status: "succeeded", finished_at: Time.current)
    task.refresh!
    assert_equal 0, sweep
  end

  test "the job does nothing without Solid Queue (the test adapter)" do
    task = per_server_task
    SweepStaleTasksJob.perform_now
    assert task.items.reload.all? { |item| item.status == "queued" }
  end
end
