require "test_helper"

class Inventory::Collectors::ScheduledTasksTest < ActiveSupport::TestCase
  Collector = Inventory::Collectors::ScheduledTasks
  NOW = Time.zone.at(1_762_000_000)

  def output(name) = file_fixture("inventory/scheduled_tasks/#{name}.txt").read

  def collect(name, sudo: true)
    known_hosts = Rails.root.join("tmp", "test", "tasks-#{SecureRandom.hex(4)}", "known_hosts")
    fake = FakeSsh.new(responses: { "sudo -n true" => FakeSsh::Response.new("", "", sudo ? 0 : 1) },
                       handler: ->(command) { FakeSsh::Response.new(output(name), "", 0) if command.include?("sh -c") })
    [ Ssh::Connection.open(servers(:web), transport: fake, known_hosts_file: known_hosts) { |ssh| Collector.new(ssh).collect }, fake.commands ]
  ensure
    FileUtils.rm_rf(known_hosts.dirname)
  end

  test "reads the system and users' crontabs, skipping comments and variables" do
    cron = Collector.parse(output(:debian13), now: NOW)["cron"]

    assert_equal 10, cron.size
    assert_equal({ "source" => "/etc/crontab", "user" => "root", "schedule" => "25 6 * * *",
                   "command" => "test -x /usr/sbin/anacron || { cd / && run-parts --report /etc/cron.daily; }" }, cron[1])
    assert_equal({ "source" => "/etc/cron.d/pg-backup", "user" => "postgres", "schedule" => "15 2 * * *",
                   "command" => "/usr/local/bin/backup.sh --all >> /var/log/pg-backup.log 2>&1" }, cron.find { |task| task["source"].end_with?("pg-backup") })
    assert_equal [ [ "crontab de root", "root", "*/5 * * * *", "/root/bin/check-disk.sh" ], [ "crontab de root", "root", "@reboot", "/root/bin/warmup.sh" ],
                   [ "crontab de deploy", "deploy", "0 */6 * * *", "cd /srv/app && ./bin/rails runner 'Cleanup.run' >/dev/null" ] ],
                 cron.last(3).map { |task| task.values_at("source", "user", "schedule", "command") }
  end

  test "lists the periodic scripts" do
    periodic = Collector.parse(output(:debian13), now: NOW)["periodic"]
    assert_equal [ %w[daily apt-compat], %w[daily dpkg], %w[daily logrotate], %w[daily man-db], %w[weekly man-db] ], periodic.map { |task| task.values_at("period", "name") }
  end

  test "reads the timers with their last run, result and next run; flags failed and late ones" do
    timers = Collector.parse(output(:debian13), now: NOW)["timers"].index_by { |timer| timer["name"] }

    assert_equal %w[apt-daily-upgrade.timer certbot.timer backup.timer systemd-tmpfiles-clean.timer fstrim.timer], timers.keys
    apt = timers["apt-daily-upgrade.timer"]
    assert_equal [ "apt-daily-upgrade.service", [ "OnCalendar=*-*-* 06:00:00" ], Time.zone.at(1_761_973_203).iso8601, "success", "enabled" ],
                 apt.values_at("unit", "schedules", "last_at", "result", "enabled")
    assert_not apt.key?("failed")
    assert_not apt.key?("late")

    assert_equal [ true, "exit-code", 1 ], timers["certbot.timer"].values_at("failed", "result", "exit_status")
    assert timers["backup.timer"]["late"], "last run 3 days ago for a daily timer"
    assert_equal [ "OnBootUSec=15min", "OnUnitActiveUSec=1d" ], timers["systemd-tmpfiles-clean.timer"]["schedules"]
    assert_not timers["systemd-tmpfiles-clean.timer"].key?("late")
    assert_equal [ "inactive", nil, nil ], timers["fstrim.timer"].values_at("active", "last_at", "late")
  end

  test "a next run long overdue makes a timer late" do
    timers = Collector.parse(output(:no_root), now: Time.zone.parse("2025-11-03 12:00"))["timers"]
    assert timers.sole["late"]
    assert_equal Time.zone.parse("2025-11-01 00:00:03 CET").iso8601, timers.sole["last_at"]
  end

  test "collects through sudo, partial when the users' crontabs cannot be read" do
    outcome, commands = collect(:debian13)
    assert_equal [ "ok", "ok" ], [ outcome.status, outcome.data["user_crontabs"] ]
    assert_includes commands, "sudo -n #{Ssh::Commands.render("inventory.scheduled_tasks")}"

    outcome, = collect(:no_root, sudo: false)
    assert_equal "partial", outcome.status
    assert_match "Crontabs des utilisateurs illisibles", outcome.message
    assert_equal 1, outcome.data["cron"].size
  end

  test "a system without cron nor systemd is unsupported" do
    assert_equal "unsupported", collect(:none).first.status
  end

  test "logs the timers that start failing or are late" do
    previous = { "timers" => [ { "name" => "certbot.timer" }, { "name" => "backup.timer", "late" => true } ] }
    data = Collector.parse(output(:debian13), now: NOW)

    assert_equal [ { kind: :scheduled_task_failed, data: { task: "certbot.timer" } } ], Collector.changes(previous, data)
    assert_empty Collector.changes(data, data)
  end

  test "failed and late timers are health reasons" do
    server = servers(:web)
    server.inventory_snapshots.create!(category: "scheduled_tasks", status: "ok", collected_at: NOW, checked_at: NOW,
                                       data: Collector.parse(output(:debian13), now: NOW))

    texts = Inventory::HealthStatus.evaluate(server.reload).reasons.map(&:text)
    assert_includes texts, "Tâche planifiée certbot en échec"
    assert_includes texts, "Tâche planifiée backup en retard"
  end
end
