require "application_system_test_case"

class TeamsTest < ApplicationSystemTestCase
  include Devise::Test::IntegrationHelpers
  include StubHelpers

  setup do
    sign_in users(:one)
    stub_method_until_teardown(AuthorizedKeysReader, :call, AuthorizedKeysReader::Result.new(keys: [], error_title: nil, error_details: nil))
    stub_method_until_teardown(AccessGrant, :call, ProfileAuthorization::Result.new(status: :added, error_title: nil, error_details: nil))
    stub_method_until_teardown(AuthorizedKeyRemoval, :call, AuthorizedKeyRemoval::Result.new(status: :removed, error_title: nil, error_details: nil))
  end

  test "creating a team from the profiles page" do
    visit profiles_path
    click_on "Équipes"
    click_on "Nouvelle équipe"

    fill_in "Nom", with: "Ops"
    check "team_profile_ids_#{profiles(:ci).id}", allow_label_click: true
    click_on "Créer l'équipe"

    assert_selector "#flash .toast", text: "L'équipe « Ops » a été créée."
    assert_selector "h1", text: "Ops"
    assert_selector "#team-members li.team-member", count: 1, text: "CI"
  end

  test "granting then revoking a team on a whole server group" do
    visit team_path(teams(:developers))

    within("#team-access") do
      click_on "Production"
      click_on "Autoriser l'équipe"
    end
    assert_selector "#flash .toast", text: "4/4 accès traités"
    assert_selector "#team-bulk-results li.bulk-result.is-success", count: 4
    assert_selector "#team-bulk-results li", text: /Alice\s+→\s+Database/

    accept_app_confirm { within("#team-access") { click_on "Retirer l'équipe" } }
    assert_selector "#flash .toast", text: "Retrait de l'équipe « Développeurs » terminé"
    assert_selector "#team-bulk-results li", text: "retiré", count: 4
  end
end
