require "test_helper"

class TeamsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers
  include ActionView::RecordIdentifier

  test "requires authentication" do
    get teams_path
    assert_redirected_to new_user_session_path
  end

  test "lists the teams with their profiles" do
    sign_in users(:one)
    get teams_path

    assert_response :success
    assert_select "nav .main-nav a[aria-current=page]", text: "Profils"
    assert_select "#teams li.team", 2
    assert_select "##{dom_id(teams(:developers))}" do
      assert_select "a[href=?]", team_path(teams(:developers)), text: "Développeurs"
      assert_select "p", text: "2 profils : Alice, CI"
    end
    assert_select "##{dom_id(teams(:oncall))} p", text: "Aucun profil"
  end

  test "shows an empty state" do
    Team.delete_all
    sign_in users(:one)
    get teams_path

    assert_select "p", text: /Aucune équipe/
    assert_select "a[href=?]", new_team_path, text: "Créer une équipe"
  end

  test "the team page lists its members and the grant / revoke form" do
    sign_in users(:one)
    get team_path(teams(:developers))

    assert_response :success
    assert_select "h1", "Développeurs"
    assert_select ".team-description", "L'équipe produit"
    assert_select "#team-members li.team-member", 2
    assert_select "#team-members a[href=?]", profile_path(profiles(:alice)), text: "Alice"
    assert_select "#team-access form[action=?]", team_accesses_path(teams(:developers)) do
      assert_select "input[type=checkbox][name='server_ids[]']", Server.count
      assert_select ".bulk-groups button", text: "Production"
      assert_select "select[name=duration]"
      assert_select "button[type=submit]", text: /Autoriser l'équipe/
      assert_select "button[name=_method][value=delete][formaction=?][data-confirm-variant=danger]", team_access_path(teams(:developers)), text: /Retirer l'équipe/
    end
  end

  test "an empty team has no grant form, viewers never do" do
    sign_in users(:one)
    get team_path(teams(:oncall))
    assert_select "#team-access", 0
    assert_select "a[href=?]", edit_team_path(teams(:oncall)), text: "Ajouter des profils"

    sign_in users(:viewer)
    get team_path(teams(:developers))
    assert_select "#team-members li.team-member", 2
    assert_select "#team-access", 0
    assert_select "a[href=?]", edit_team_path(teams(:developers)), 0
  end

  test "creates a team with profiles and logs it" do
    sign_in users(:one)

    assert_difference -> { Team.count } => 1, -> { Activity.of_kind(:team_created).count } => 1 do
      post teams_path, params: { team: { name: "Ops", description: "Infra", profile_ids: [ "", profiles(:ci).id ] } }
    end

    team = Team.find_by!(name: "Ops")
    assert_redirected_to team_path(team)
    assert_equal [ profiles(:ci) ], team.profiles.to_a
    assert_equal "Équipe « Ops » créée (1 profil(s))", Activity.last.summary
  end

  test "the new form can be prefilled and lists every profile" do
    sign_in users(:one)
    get new_team_path(profile_ids: [ profiles(:alice).id ])

    assert_select "input[type=checkbox][name='team[profile_ids][]']", Profile.count
    assert_select "input[type=checkbox][value=?][checked]", profiles(:alice).id.to_s
  end

  test "re-renders the form when invalid" do
    sign_in users(:one)

    assert_no_difference("Team.count") { post teams_path, params: { team: { name: "DÉVELOPPEURS" } } }
    assert_response :unprocessable_entity
    assert_select "#error_explanation li"
  end

  test "updates the team and can empty it" do
    sign_in users(:one)
    team = teams(:developers)

    patch team_path(team), params: { team: { name: "Devs", description: "", profile_ids: [ "" ] } }

    assert_redirected_to team_path(team)
    team.reload
    assert_equal "Devs", team.name
    assert_nil team.description
    assert_empty team.profiles
  end

  test "deletes the team, keeping its profiles" do
    sign_in users(:one)

    assert_no_difference("Profile.count") { delete team_path(teams(:developers)) }

    assert_redirected_to teams_path
    assert_response :see_other
    assert_not Team.exists?(teams(:developers).id)
    assert_equal "Équipe « Développeurs » supprimée", Activity.last.summary
  end

  test "returns 404 for an unknown team" do
    sign_in users(:one)
    get team_path(id: 0)
    assert_response :not_found
  end

  test "profiles show their teams" do
    sign_in users(:one)

    get profiles_path
    assert_select "##{dom_id(profiles(:alice))} a.team-badge[href=?]", team_path(teams(:developers)), text: "Développeurs"
    assert_select "a[href=?]", teams_path, text: "Équipes"

    get profile_path(profiles(:alice))
    assert_select ".profile-teams a.team-badge", "Développeurs"
  end
end
