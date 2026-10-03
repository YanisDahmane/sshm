require "test_helper"

class DriftFixesControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers
  include StubHelpers

  setup do
    AccessRule.create!(team: teams(:developers), server_group: server_groups(:production))
    AccountSnapshot.create!(server: servers(:web), unix_user: "deploy", read_at: 1.minute.ago, content: profiles(:ci).public_key)
    AccountSnapshot.create!(server: servers(:db), unix_user: "admin", read_at: 1.minute.ago, content: "")
    stub_method_until_teardown(AuthorizedKeysReader, :call, AuthorizedKeysReader::Result.new(keys: [], error_title: nil, error_details: nil))
  end

  def granter(calls, failing: nil)
    lambda do |server, profile, account:, duration:|
      calls << [ server.name, profile.name, account.unix_user ]
      failed = server == failing
      ProfileAuthorization::Result.new(status: failed ? :error : :added, error_title: (failed ? "Connexion impossible" : nil), error_details: (failed ? "timeout" : nil))
    end
  end

  test "requires authentication" do
    post drift_fix_path
    assert_redirected_to new_user_session_path
  end

  test "adds the missing keys of one account" do
    sign_in users(:operator)
    calls = []

    stub_method(AccessGrant, :call, granter(calls)) { post drift_fix_path, params: { server_id: servers(:web).id, account: "deploy" } }

    assert_redirected_to drift_path
    assert_equal [ [ "Web", "Alice", "deploy" ] ], calls
    assert_equal "1/1 clé(s) manquante(s) ajoutée(s).", flash[:notice]
  end

  test "adds the missing keys of every account and reports failures" do
    sign_in users(:one)
    calls = []

    stub_method(AccessGrant, :call, granter(calls, failing: servers(:db))) { post drift_fix_path }

    assert_equal [ [ "Database", "Alice", "admin" ], [ "Database", "CI", "admin" ], [ "Web", "Alice", "deploy" ] ], calls
    assert_match "1/3 clé(s) manquante(s) ajoutée(s). Échecs : Alice sur Database (Connexion impossible — timeout)", flash[:alert]
  end

  test "nothing to add" do
    sign_in users(:one)

    stub_method(AccessGrant, :call, ->(*) { flunk "must not grant" }) { post drift_fix_path, params: { server_id: servers(:backup).id, account: "root" } }

    assert_redirected_to drift_path
    assert_equal "Aucune clé manquante à ajouter.", flash[:alert]
  end

  test "removes one extra key from an account" do
    sign_in users(:one)
    blob = profiles(:ci).authorized_key.key
    removed = []

    stub_method(AuthorizedKeyRemoval, :call, ->(server, key, account:, **) { removed << [ server.name, key, account.unix_user ]; AuthorizedKeyRemoval::Result.new(status: :removed, error_title: nil, error_details: nil) }) do
      delete drift_fix_path, params: { server_id: servers(:web).id, account: "deploy", key: blob, name: "ci@runner" }
    end

    assert_redirected_to drift_path
    assert_equal [ [ "Web", blob, "deploy" ] ], removed
    assert_equal "Clé « ci@runner » retirée de « Web » pour deploy.", flash[:notice]
    activity = Activity.of_kind(:key_removed).sole
    assert_equal profiles(:ci), activity.profile
  end

  test "reports a failed removal and rejects an invalid account" do
    sign_in users(:one)

    stub_method(AuthorizedKeyRemoval, :call, AuthorizedKeyRemoval::Result.new(status: :error, error_title: "Connexion impossible", error_details: "timeout")) do
      delete drift_fix_path, params: { server_id: servers(:web).id, account: "deploy", key: "AAAA" }
    end
    assert_equal "Impossible de retirer la clé : Connexion impossible — timeout", flash[:alert]

    delete drift_fix_path, params: { server_id: servers(:web).id, account: "bad name;", key: "AAAA" }
    assert_response :bad_request
  end
end
