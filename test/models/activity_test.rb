require "test_helper"

class ActivityTest < ActiveSupport::TestCase
  teardown { Current.reset }

  test "every kind has a label, a known category and a known severity" do
    Activity::KINDS.each_value do |kind|
      assert kind.label.present?, kind.key
      assert kind.description.present?, kind.key
      assert_includes Activity::CATEGORIES.keys, kind.category, kind.key
      assert_includes Activity::SEVERITIES, kind.severity, kind.key
    end
  end

  test "rejects an unknown kind" do
    assert_not Activity.new(kind: "nope").valid?
    assert_raises(ActiveRecord::RecordInvalid) { Activity.record!(:nope) }
  end

  test "record! copies names and defaults the author to the current user" do
    Current.user = users(:one)

    activity = Activity.record!(:key_added, server: servers(:web), profile: profiles(:alice), unix_user: "deploy", key_name: "alice@laptop")

    assert_equal users(:one), activity.user
    assert_equal "one@example.com", activity.author_name
    assert_equal({ "key_name" => "alice@laptop", "server_name" => "Web", "profile_name" => "Alice" }, activity.data)
    assert_equal "Clé ajoutée", activity.label
    assert_equal :keys, activity.category
    assert_equal :info, activity.severity
  end

  test "without a current user the author is the system" do
    assert_equal "Système", Activity.record!(:server_unreachable, server: servers(:web)).author_name
  end

  test "stays readable once the server and the profile are deleted" do
    activity = Activity.record!(:key_added, server: servers(:web), profile: profiles(:alice), unix_user: "deploy")
    profiles(:alice).destroy!
    servers(:web).destroy!

    activity.reload
    assert_nil activity.server
    assert_equal "« Alice » autorisé sur « Web » pour deploy", activity.summary
  end

  test "summaries" do
    web = servers(:web)
    {
      [ :key_added, { profile: profiles(:alice), unix_user: "deploy", duration_label: "10 minutes" } ] => "« Alice » autorisé sur « Web » pour deploy pendant 10 minutes",
      [ :key_removed, { unix_user: "root", key_name: "bob" } ] => "Clé « bob » supprimée de « Web » pour root",
      [ :key_expired, { profile: profiles(:ci), unix_user: "deploy" } ] => "Accès temporaire de « CI » retiré de « Web » pour deploy",
      [ :unknown_key_detected, { unix_user: "root" } ] => "Clé « sans nom » sans profil trouvée sur « Web » pour root",
      [ :key_disappeared, { unix_user: "root", key_name: "bob" } ] => "Clé « bob » disparue de « Web » pour root",
      [ :ssh_access_lost, {} ] => "« Web » refuse la clé de SSHM",
      [ :host_key_changed, { new_fingerprint: "SHA256:new" } ] => "Nouvelle empreinte acceptée pour « Web » : SHA256:new",
      [ :server_unreachable, {} ] => "« Web » ne répond plus",
      [ :server_back_online, {} ] => "« Web » répond à nouveau",
      [ :server_created, {} ] => "Serveur « Web » ajouté",
      [ :server_updated, {} ] => "Serveur « Web » modifié"
    }.each do |(kind, options), summary|
      assert_equal summary, Activity.record!(kind, server: web, **options).summary, kind
    end

    assert_equal "Profil « Alice » créé", Activity.record!(:profile_created, profile: profiles(:alice)).summary
    assert_equal "Profil « Bob » supprimé", Activity.record!(:profile_deleted, profile_name: "Bob").summary
    assert_equal "Clé SSHM générée", Activity.record!(:ssh_key_generated, regenerated: false).summary
    assert_equal "Clé SSHM régénérée", Activity.record!(:ssh_key_generated, regenerated: true).summary
    assert_equal "Scan des clés : 2/2", Activity.record!(:automation_run, automation_label: "Scan des clés", result: "2/2").summary
  end

  test "scopes" do
    old = travel_to(1.hour.ago) { Activity.record!(:server_created, server: servers(:web)) }
    added = Activity.record!(:key_added, server: servers(:web))
    detected = Activity.record!(:unknown_key_detected, server: servers(:web))

    assert_equal [ detected, added, old ], Activity.recent.to_a
    assert_equal [ added ], Activity.of_kind(:key_added).to_a
    assert_equal [ detected ], Activity.in_category(:security).to_a
    assert_equal [ old ], Activity.in_category("servers").to_a
  end

  test "server_deleted summary uses the copied name" do
    activity = Activity.record!(:server_deleted, server_name: "Web")
    assert_equal "Serveur « Web » supprimé de SSHM", activity.summary
    assert_equal :warning, activity.severity
  end
end
