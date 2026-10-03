require "application_system_test_case"

class AccessRequestsTest < ApplicationSystemTestCase
  include Devise::Test::IntegrationHelpers
  include StubHelpers

  setup do
    users(:viewer).update!(profile: profiles(:ci))
    stub_method_until_teardown(AccessGrant, :call, ProfileAuthorization::Result.new(status: :added, error_title: nil, error_details: nil))
    stub_method_until_teardown(AuthorizedKeysReader, :call, AuthorizedKeysReader::Result.new(keys: [], error_title: nil, error_details: nil))
  end

  test "a viewer requests an access and an admin approves it" do
    sign_in users(:viewer)
    visit server_path(servers(:web))
    click_on "Demander un accès"

    select "30 minutes", from: "Durée"
    fill_in "Motif", with: "Lire les logs de l'incident"
    click_on "Envoyer la demande"
    assert_selector "#flash .toast", text: "Demande envoyée"
    assert_selector "#my-requests .request-status", text: "En attente"

    sign_in users(:one)
    visit access_requests_path
    within("#pending-requests") { click_on "Accepter" }

    assert_selector "#flash .toast", text: "Accès accordé à viewer@example.com sur « Web » pendant 30 minutes."
    assert_selector "#pending-requests", text: "Aucune demande en attente."
    assert_selector "#requests-history .request-status", text: "Acceptée"
  end
end
