require "test_helper"

class TeamAccessesControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers
  include StubHelpers

  setup do
    @team = teams(:developers)
    stub_method_until_teardown(AuthorizedKeysReader, :call, AuthorizedKeysReader::Result.new(keys: [], error_title: nil, error_details: nil))
  end

  def grant_result(status) = ProfileAuthorization::Result.new(status: status, error_title: (status == :error ? "Connexion impossible" : nil), error_details: (status == :error ? "timeout" : nil))

  test "requires authentication" do
    post team_accesses_path(@team), params: { server_ids: [ servers(:web).id ] }
    assert_redirected_to new_user_session_path
  end

  test "grants every member on the chosen servers and lists each outcome" do
    sign_in users(:one)
    calls = []
    granter = ->(server, profile, account:, duration:) { calls << [ server.name, profile.name, account.unix_user, duration ]; grant_result(:added) }

    stub_method(AccessGrant, :call, granter) do
      post team_accesses_path(@team), params: { server_ids: [ servers(:web).id, servers(:backup).id ], duration: "30" }, as: :turbo_stream
    end

    assert_response :success
    assert_equal [ [ "Backup", "Alice", "root", 30.minutes ], [ "Backup", "CI", "root", 30.minutes ], [ "Web", "Alice", "deploy", 30.minutes ], [ "Web", "CI", "deploy", 30.minutes ] ], calls
    assert_turbo_stream action: :update, target: "flash" do
      assert_select ".toast-notice", text: /Autorisation de l'équipe « Développeurs » terminé : 4\/4 accès traités\./
    end
    assert_turbo_stream action: :update, target: "team-bulk-results" do
      assert_select "li.bulk-result.is-success", 4
      assert_select "li.bulk-result", text: /Alice\s+→\s+Backup · root : autorisé pendant 30 minutes/
    end
  end

  test "reports failures as an alert" do
    sign_in users(:one)

    stub_method(AccessGrant, :call, ->(_server, profile, **) { grant_result(profile.name == "CI" ? :error : :added) }) do
      post team_accesses_path(@team), params: { server_ids: [ servers(:web).id ] }, as: :turbo_stream
    end

    assert_turbo_stream action: :update, target: "flash" do
      assert_select ".toast-alert", text: /1\/2 accès traités, 1 échec\(s\)/
    end
    assert_turbo_stream action: :update, target: "team-bulk-results" do
      assert_select "li.bulk-result.is-error", text: /CI\s+→\s+Web · deploy : Connexion impossible — timeout/
    end
  end

  test "revokes every member from the chosen servers on the named account" do
    sign_in users(:one)
    calls = []
    remover = ->(server, blob, account:, **) { calls << [ server.name, blob, account.unix_user ]; AuthorizedKeyRemoval::Result.new(status: :removed, error_title: nil, error_details: nil) }

    stub_method(AuthorizedKeyRemoval, :call, remover) do
      delete team_access_path(@team), params: { server_ids: [ servers(:web).id ], account: "debian" }
    end

    assert_redirected_to team_path(@team)
    assert_response :see_other
    assert_equal [ [ "Web", profiles(:alice).authorized_key.key, "debian" ], [ "Web", profiles(:ci).authorized_key.key, "debian" ] ], calls
    assert_match "Retrait de l'équipe « Développeurs » terminé : 2/2", flash[:notice]
    assert_equal 2, Activity.of_kind(:key_removed).count
  end

  test "asks to choose a server, and refuses an empty team" do
    sign_in users(:one)

    post team_accesses_path(@team)
    assert_redirected_to team_path(@team)
    assert_equal "Choisissez au moins un serveur.", flash[:alert]

    post team_accesses_path(teams(:oncall)), params: { server_ids: [ servers(:web).id ] }
    assert_equal "L'équipe n'a aucun profil.", flash[:alert]
  end

  test "rejects a duration that is not offered" do
    sign_in users(:one)
    post team_accesses_path(@team), params: { server_ids: [ servers(:web).id ], duration: "7" }
    assert_response :bad_request
  end

  test "viewers cannot grant or revoke" do
    sign_in users(:viewer)

    stub_method(AccessGrant, :call, ->(*) { flunk "must not grant" }) do
      post team_accesses_path(@team), params: { server_ids: [ servers(:web).id ] }
    end
    assert_response :forbidden
  end
end
