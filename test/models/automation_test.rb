require "test_helper"

class AutomationTest < ActiveSupport::TestCase
  include StubHelpers

  test "all_kinds creates every automation once, disabled with its default interval" do
    automations = Automation.all_kinds

    assert_equal %w[keys_scan servers_ping drift_check], automations.map(&:kind)
    assert_equal [ 360, 15, 360 ], automations.map(&:interval_minutes)
    assert automations.none?(&:enabled?)
    assert_equal automations, Automation.all_kinds
    assert_equal 3, Automation.count
    assert automations.none?(&:auto_fix?)
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

  def snapshot(server, unix_user, *profiles)
    AccountSnapshot.create!(server: server, unix_user: unix_user, read_at: 1.minute.ago,
                            content: profiles.map { |profile| profile.public_key }.join("\n"))
  end

  test "the drift check scans the covered servers and logs new drift only once" do
    automation = Automation.all_kinds.find { |a| a.kind == "drift_check" }
    AccessRule.create!(profile: profiles(:alice), server: servers(:web))
    snapshot(servers(:web), "deploy", profiles(:ci))
    scanned = []

    result = stub_method(ServerScan, :call, ->(server, **) { scanned << server.name; ServerScan::Result.new(accounts: [], error_title: nil) }) do
      automation.run!
    end

    assert_equal [ "Web" ], scanned
    assert_equal "1 compte(s) en écart : 1 clé(s) manquante(s), 1 en trop", result
    assert_equal "Écarts avec les règles d'accès : 1 clé(s) manquante(s), 1 clé(s) en trop", Activity.of_kind(:access_drift_detected).sole.summary
    assert_equal 2, automation.reload.state["signature"].size

    stub_method(ServerScan, :call, ServerScan::Result.new(accounts: [], error_title: nil)) { automation.run! }
    assert_equal 1, Activity.of_kind(:access_drift_detected).count, "same drift: not logged again"
  end

  test "the drift check can add the missing keys, never removes any, and reports unread accounts" do
    automation = Automation.all_kinds.find { |a| a.kind == "drift_check" }
    automation.update!(auto_fix: true)
    AccessRule.create!(profile: profiles(:alice), server_group: server_groups(:production))
    snapshot(servers(:web), "deploy", profiles(:ci))
    granted = []
    granter = lambda do |server, profile, account:, duration:|
      granted << [ server.name, profile.name, account.unix_user ]
      AccountSnapshot.find_by!(server: server, unix_user: account.unix_user).tap { |s| s.update!(content: "#{s.content}\n#{profile.public_key}") }
      ProfileAuthorization::Result.new(status: :added, error_title: nil, error_details: nil)
    end

    result = stub_method(ServerScan, :call, ServerScan::Result.new(accounts: [], error_title: nil)) do
      stub_method(AuthorizedKeysReader, :call, AuthorizedKeysReader::Result.new(keys: [], error_title: "x", error_details: "y")) do
        stub_method(AccessGrant, :call, granter) { automation.run! }
      end
    end

    assert_equal [ [ "Web", "Alice", "deploy" ] ], granted, "the never read Database account is left alone"
    assert_equal "1 compte(s) en écart : 0 clé(s) manquante(s), 1 en trop, 1 clé(s) ajoutée(s) automatiquement, 1 compte(s) jamais lu(s)", result
    assert_includes AccountSnapshot.find_by!(server: servers(:web), unix_user: "deploy").fingerprints, profiles(:ci).fingerprint
  end
end
