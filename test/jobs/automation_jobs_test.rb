require "test_helper"

class AutomationJobsTest < ActiveJob::TestCase
  include StubHelpers

  test "RunAutomationJob runs the automation" do
    automation = Automation.all_kinds.find { |automation| automation.kind == "keys_scan" }
    ran = []
    automation.define_singleton_method(:run!) { ran << kind }

    RunAutomationJob.perform_now(automation)

    assert_equal [ "keys_scan" ], ran
  end

  test "RunDueAutomationsJob starts only the enabled automations that are due" do
    automations = Automation.all_kinds.index_by(&:kind)
    automations.each_value { |automation| automation.update!(enabled: false) }
    scan, ping = automations.values_at("keys_scan", "servers_ping")
    scan.update!(enabled: true, interval_minutes: 60, last_run_at: 2.hours.ago)
    ping.update!(enabled: true, interval_minutes: 15, last_run_at: 5.minutes.ago)

    freeze_time do
      RunDueAutomationsJob.perform_now

      assert_enqueued_jobs 1, only: RunAutomationJob
      assert_enqueued_with(job: RunAutomationJob, args: [ scan ])
      assert_equal Time.current, scan.reload.last_run_at
    end
  end

  test "RunDueAutomationsJob ignores disabled automations" do
    Automation.all_kinds.each { |automation| automation.update!(enabled: false) }

    RunDueAutomationsJob.perform_now

    assert_no_enqueued_jobs only: RunAutomationJob
  end

  test "on a new installation, the first tick creates the automations and starts the health check" do
    RunDueAutomationsJob.perform_now

    assert_equal 7, Automation.count
    assert_enqueued_with(job: RunAutomationJob, args: [ Automation.find_by!(kind: "health_check") ])
    assert_enqueued_jobs 1, only: RunAutomationJob
  end

  test "due automations are checked every minute in development and production" do
    recurring = YAML.load_file(Rails.root.join("config/recurring.yml"), aliases: true)
    %w[development production].each do |environment|
      assert_equal({ "class" => "RunDueAutomationsJob", "schedule" => "every minute" }, recurring.dig(environment, "run_due_automations"))
    end
  end
end
