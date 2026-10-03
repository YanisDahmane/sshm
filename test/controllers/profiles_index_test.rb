require "test_helper"

class ProfilesIndexTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  test "requires authentication" do
    get profiles_path
    assert_redirected_to new_user_session_path
  end

  test "lists profiles sorted by name with their actions" do
    sign_in users(:one)
    get profiles_path

    assert_select "#profiles-section a[href=?]", new_profile_path, text: "Ajouter un profil"
    assert_select "#profiles tbody tr", 2
    assert_select "#profiles tbody tr:first-child td:first-child", "Alice"
    Profile.find_each do |profile|
      assert_select "##{ActionView::RecordIdentifier.dom_id(profile)}" do
        assert_select "td a[href=?]", profile_path(profile), text: profile.name
        assert_select "td", text: "ssh-ed25519"
        assert_select "td", text: profile.fingerprint
        assert_select "a[href=?][title=Modifier]", edit_profile_path(profile)
        assert_select "form[action=?][data-turbo-confirm] button[title=Supprimer]", profile_path(profile)
      end
    end
  end

  test "shows an empty state when there are no profiles" do
    Profile.delete_all
    sign_in users(:one)
    get profiles_path

    assert_select "#profiles", 0
    assert_select "#profiles-section p", text: "Aucun profil pour le moment."
  end
end
