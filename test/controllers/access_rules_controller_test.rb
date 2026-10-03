require "test_helper"

class AccessRulesControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers
  include ActionView::RecordIdentifier

  test "requires authentication" do
    get access_rules_path
    assert_redirected_to new_user_session_path
  end

  test "lists the rules with the tabs and the form" do
    rule = AccessRule.create!(team: teams(:developers), server_group: server_groups(:production), unix_user: "deploy", created_by: users(:one))
    sign_in users(:one)

    get access_rules_path

    assert_response :success
    assert_select "nav .main-nav a[aria-current=page]", text: "Accès"
    assert_select "nav.access-tabs a[aria-current=page]", "Règles"
    assert_select "nav.access-tabs a[href=?]", drift_path
    assert_select "##{dom_id(rule)}" do
      assert_select "a[href=?]", team_path(teams(:developers)), text: "Développeurs"
      assert_select "span", text: "équipe · 2 profils"
      assert_select "a.server-group-badge", "Production"
      assert_select "span.font-mono", "deploy"
      assert_select "form[action=?][data-turbo-confirm]", access_rule_path(rule)
    end
    assert_select "#new-access-rule form[action=?]", access_rules_path do
      assert_select "select[name='access_rule[subject_key]'] optgroup[label=Équipes] option[value=?]", "team:#{teams(:developers).id}"
      assert_select "select[name='access_rule[subject_key]'] optgroup[label=Profils] option[value=?]", "profile:#{profiles(:alice).id}"
      assert_select "select[name='access_rule[target_key]'] optgroup[label=Groupes] option[value=?]", "server_group:#{server_groups(:production).id}"
      assert_select "select[name='access_rule[target_key]'] optgroup[label=Serveurs] option[value=?]", "server:#{servers(:web).id}"
    end
  end

  test "shows an empty state, and viewers get no form nor delete buttons" do
    sign_in users(:viewer)
    get access_rules_path

    assert_select "p", text: /Aucune règle/
    assert_select "#new-access-rule", 0

    AccessRule.create!(profile: profiles(:alice), server: servers(:web))
    get access_rules_path
    assert_select "li.access-rule", 1
    assert_select "li.access-rule form", 0
  end

  test "creates a rule and logs it" do
    sign_in users(:one)

    assert_difference -> { AccessRule.count } => 1, -> { Activity.of_kind(:access_rule_created).count } => 1 do
      post access_rules_path, params: { access_rule: { subject_key: "profile:#{profiles(:alice).id}", target_key: "server:#{servers(:web).id}", unix_user: "" } }
    end

    assert_redirected_to access_rules_path
    rule = AccessRule.last
    assert_equal [ profiles(:alice), servers(:web), nil, users(:one) ], [ rule.profile, rule.server, rule.unix_user, rule.created_by ]
    assert_equal "Règle ajoutée : Alice → Web (utilisateur SSH)", Activity.last.summary
    assert_match "Consultez les écarts", flash[:notice]
  end

  test "re-renders with errors for an incomplete or duplicate rule" do
    sign_in users(:one)

    post access_rules_path, params: { access_rule: { subject_key: "", target_key: "server:#{servers(:web).id}" } }
    assert_response :unprocessable_entity
    assert_select "#error_explanation li", text: /Profil ou équipe/

    AccessRule.create!(profile: profiles(:alice), server: servers(:web))
    post access_rules_path, params: { access_rule: { subject_key: "profile:#{profiles(:alice).id}", target_key: "server:#{servers(:web).id}" } }
    assert_response :unprocessable_entity
    assert_select "#error_explanation li", text: "Cette règle existe déjà"
  end

  test "deletes a rule without touching the servers" do
    rule = AccessRule.create!(profile: profiles(:alice), server: servers(:web))
    sign_in users(:one)

    delete access_rule_path(rule)

    assert_redirected_to access_rules_path
    assert_response :see_other
    assert_not AccessRule.exists?(rule.id)
    assert_equal "Règle supprimée : Alice → Web (utilisateur SSH)", Activity.last.summary
  end
end
