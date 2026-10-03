require "application_system_test_case"

class RevocationsTest < ApplicationSystemTestCase
  include Devise::Test::IntegrationHelpers
  include StubHelpers
  include ActiveJob::TestHelper

  test "revoking a profile everywhere and deleting it afterwards" do
    stub_method_until_teardown(ServerAccountsReader, :call, ->(server, **) { ServerAccountsReader::Result.new(accounts: [ AuthorizedKeysAccount.login(server) ], error_title: nil, error_details: nil) })
    stub_method_until_teardown(AuthorizedKeyRemoval, :call, AuthorizedKeyRemoval::Result.new(status: :removed, error_title: nil, error_details: nil))
    sign_in users(:one)
    visit profile_path(profiles(:alice))

    click_on "Révoquer partout"
    within("dialog[open]") do
      assert_text "Révoquer « Alice » partout ?"
      check "Supprimer le profil ensuite"
      click_on "Révoquer partout"
    end

    assert_selector "h1", text: "Révocation de « Alice »"
    assert_selector ".revocation-status", text: "En cours : 0/3 serveur(s) traité(s)"
    perform_enqueued_jobs # the page refreshes itself and shows the result
    assert_selector ".revocation-status", text: "Terminée : la clé a été retirée de 3 comptes. Le profil a été supprimé."
    assert_selector "li.revocation-step.is-removed", count: 3
    assert_not Profile.exists?(profiles(:alice).id)
  end
end
