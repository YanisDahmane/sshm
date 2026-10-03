require "application_system_test_case"

class InvitationsTest < ApplicationSystemTestCase
  include Devise::Test::IntegrationHelpers

  test "an admin invites an operator who joins through the link" do
    sign_in users(:one)
    visit settings_users_path

    fill_in "Email", with: "dave@example.com"
    select "Opérateur", from: "Rôle"
    click_on "Créer l'invitation"

    assert_text "Invitation créée pour dave@example.com."
    link = find("input.invitation-link").value
    assert_match %r{/invitations/\S+\z}, link

    find("nav button", text: "Déconnexion").click
    assert_selector "h2", text: "Connexion"

    visit URI(link).path
    assert_text "one@example.com vous invite avec le rôle Opérateur"
    fill_in "Mot de passe", with: "password123", match: :prefer_exact
    fill_in "Confirmation du mot de passe", with: "password123"
    click_on "Créer mon compte"

    assert_text "Bienvenue sur SSHM !"
    assert_selector "nav .user-role", text: "Opérateur"
    assert_no_selector "nav a[title=Paramètres]"
  end
end
