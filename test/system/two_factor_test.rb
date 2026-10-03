require "application_system_test_case"

class TwoFactorTest < ApplicationSystemTestCase
  include Devise::Test::IntegrationHelpers

  test "enabling 2FA, then signing in with a code" do
    sign_in users(:operator)
    visit root_path
    find("nav a.account-link").click
    click_on "Activer la double authentification"

    assert_selector ".two-factor-qr img"
    secret = find(".two-factor-secret").text.delete(" ")
    find("input[name=code]").fill_in(with: ROTP::TOTP.new(secret).now)
    click_on "Activer"

    assert_text "Double authentification activée."
    assert_selector "textarea.backup-codes"
    click_on "J'ai enregistré mes codes"
    assert_selector ".two-factor-state", text: "Activée"

    find("nav button", text: "Déconnexion").click
    fill_in "Email", with: "operator@example.com"
    fill_in "Mot de passe", with: "password123"
    click_on "Se connecter"

    assert_selector "h2", text: "Double authentification"
    fill_in "Code", with: ROTP::TOTP.new(secret).at(Time.now + 30) # the enabling code's time step is used
    click_on "Vérifier"

    assert_text "Connexion réussie."
    assert_selector "nav .user-role", text: "Opérateur"
  end
end
