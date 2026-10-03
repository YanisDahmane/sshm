require "application_system_test_case"

class SignInTest < ApplicationSystemTestCase
  test "signing in through the form opens a session" do
    visit new_user_session_path
    fill_in "Email", with: "viewer@example.com"
    fill_in "Mot de passe", with: "password123"
    click_on "Se connecter"

    assert_selector "h1", text: "Dashboard"
    click_on "Serveurs", match: :first
    assert_selector "h1", text: "Serveurs"
    assert_selector "nav .user-role", text: "Lecture"
  end
end
