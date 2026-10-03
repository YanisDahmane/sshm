require "application_system_test_case"

class ProfilesTest < ApplicationSystemTestCase
  include Devise::Test::IntegrationHelpers
  include ActionView::RecordIdentifier

  setup do
    sign_in users(:one)
  end

  test "creating, editing and deleting a profile" do
    key = SshKeyGenerator.generate(comment: "bob@desktop")
    visit root_path

    click_on "Ajouter un profil"
    fill_in "Nom", with: "Bob"
    fill_in "Clé SSH publique", with: key.public_key
    click_on "Ajouter le profil"

    assert_text "Le profil « Bob » a été ajouté."
    within("#profiles") { click_on "Bob" }
    assert_selector "#profile-fingerprint", text: key.fingerprint

    click_on "Modifier"
    fill_in "Nom", with: "Bob Martin"
    click_on "Enregistrer"
    assert_text "Le profil « Bob Martin » a été modifié."

    accept_confirm { click_on "Supprimer" }
    assert_text "Le profil « Bob Martin » a été supprimé."
    assert_no_selector "#profiles", text: "Bob Martin"
  end

  test "deleting from the dashboard can be cancelled" do
    visit root_path

    within("##{dom_id(profiles(:alice))}") do
      dismiss_confirm { click_on "Supprimer" }
    end
    assert_selector "#profiles", text: "Alice"

    within("##{dom_id(profiles(:alice))}") do
      accept_confirm { click_on "Supprimer" }
    end
    assert_text "Le profil « Alice » a été supprimé."
  end

  test "invalid key shows the errors" do
    visit new_profile_path
    fill_in "Nom", with: "Broken"
    fill_in "Clé SSH publique", with: "not a key"
    click_on "Ajouter le profil"

    assert_selector "#error_explanation", text: "must be a single SSH public key"
  end
end
