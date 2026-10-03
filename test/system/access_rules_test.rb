require "application_system_test_case"

class AccessRulesTest < ApplicationSystemTestCase
  include Devise::Test::IntegrationHelpers
  include StubHelpers

  setup do
    sign_in users(:one)
    AccountSnapshot.create!(server: servers(:web), unix_user: "deploy", read_at: 1.minute.ago, content: "")
    granter = lambda do |server, profile, account:, **|
      snapshot = AccountSnapshot.find_by!(server: server, unix_user: account.unix_user)
      snapshot.update!(content: [ snapshot.content, profile.public_key ].reject(&:blank?).join("\n"))
      ProfileAuthorization::Result.new(status: :added, error_title: nil, error_details: nil)
    end
    stub_method_until_teardown(AccessGrant, :call, granter)
    stub_method_until_teardown(AuthorizedKeysReader, :call, AuthorizedKeysReader::Result.new(keys: [], error_title: "x", error_details: "y"))
  end

  test "adding a rule, seeing the drift and fixing it" do
    visit root_path
    within("nav .main-nav") { click_on "Accès" }

    select "Alice", from: "Profil ou équipe"
    select "Web", from: "Serveur ou groupe"
    click_on "Ajouter la règle"
    assert_selector "#flash .toast", text: "Règle ajoutée : Alice → Web (utilisateur SSH)"

    click_on "Écarts"
    assert_selector ".drift-entry.is-drift .drift-missing", text: "Alice"

    click_on "Ajouter les clés manquantes"
    assert_selector "#flash .toast", text: "1/1 clé(s) manquante(s) ajoutée(s)."
    assert_selector ".drift-entry.is-clean .drift-state", text: "Conforme"
    assert_no_selector "nav.access-tabs .drift-count"
  end
end
