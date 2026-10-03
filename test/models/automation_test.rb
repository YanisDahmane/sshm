require "test_helper"

class AutomationTest < ActiveSupport::TestCase
  include StubHelpers

  test "all_kinds creates every automation once, disabled with its default interval" do
    automations = Automation.all_kinds

    assert_equal %w[keys_scan servers_ping], automations.map(&:kind)
    assert_equal [ 360, 15 ], automations.map(&:interval_minutes)
    assert automations.none?(&:enabled?)
    assert_equal automations, Automation.all_kinds
    assert_equal 2, Automation.count
  end

  test "validations" do
    automation = Automation.new(kind: "nope", interval_minutes: 7)
    assert_not automation.valid?
    assert automation.errors.key?(:kind)
    assert automation.errors.key?(:interval_minutes)

    Automation.all_kinds
    assert_not Automation.new(kind: "keys_scan", interval_minutes: 60).valid?
  end

  test "due? and next_run_at" do
    automation = Automation.all_kinds.first
    freeze_time do
      assert_not automation.due?
      assert_nil automation.next_run_at

      automation.update!(enabled: true, interval_minutes: 60)
      assert automation.due?
      assert_equal Time.current, automation.next_run_at

      automation.update!(last_run_at: 59.minutes.ago)
      assert_not automation.due?
      assert_equal 1.minute.from_now, automation.next_run_at

      automation.update!(last_run_at: 60.minutes.ago)
      assert automation.due?
    end
  end

  test "the keys scan scans every server and counts the new keys without profile" do
    automation = Automation.all_kinds.find { |a| a.kind == "keys_scan" }
    scan = lambda do |server, **|
      Activity.record!(:unknown_key_detected, server: server) if server.name == "Web"
      ServerScan::Result.new(accounts: [], error_title: (server.name == "Backup" ? "Connexion impossible" : nil))
    end

    result = stub_method(ServerScan, :call, scan) { automation.run! }

    assert_equal "2/3 serveur(s) scanné(s), 1 nouvelle(s) clé(s) sans profil", result
    assert_equal result, automation.reload.last_result
    assert_not_nil automation.last_run_at
    activity = Activity.of_kind(:automation_run).sole
    assert_equal "Scan des clés : #{result}", activity.summary
    assert_equal "Système", activity.author_name
  end

  test "the servers check pings every server" do
    automation = Automation.all_kinds.find { |a| a.kind == "servers_ping" }

    result = stub_method(ServerPing, :check_all!, ->(servers, **) { servers.to_a.index_with { |server| server.name != "Database" } }) { automation.run! }

    assert_equal "2/3 serveur(s) joignable(s)", result
  end
end
