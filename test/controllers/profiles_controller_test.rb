require "test_helper"

class ProfilesControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @key = SshKeyGenerator.generate(comment: "bob@desktop")
  end

  def valid_params
    { profile: { name: "Bob", public_key: @key.public_key } }
  end

  test "every action requires authentication" do
    profile = profiles(:alice)

    get new_profile_path
    assert_redirected_to new_user_session_path
    get profile_path(profile)
    assert_redirected_to new_user_session_path
    get edit_profile_path(profile)
    assert_redirected_to new_user_session_path

    assert_no_difference "Profile.count" do
      post profiles_path, params: valid_params
    end
    assert_redirected_to new_user_session_path

    patch profile_path(profile), params: { profile: { name: "Hacked" } }
    assert_redirected_to new_user_session_path
    assert_equal "Alice", profile.reload.name

    assert_no_difference "Profile.count" do
      delete profile_path(profile)
    end
    assert_redirected_to new_user_session_path
  end

  test "new renders the form" do
    sign_in users(:one)
    get new_profile_path

    assert_response :success
    assert_select "form[action=?]", profiles_path do
      assert_select "input[name='profile[name]']"
      assert_select "textarea[name='profile[public_key]']"
      assert_select "input[type=submit][value='Ajouter le profil']"
    end
  end

  test "create saves the profile and redirects to its page" do
    sign_in users(:one)

    assert_difference "Profile.count", 1 do
      post profiles_path, params: valid_params
    end

    profile = Profile.find_by!(name: "Bob")
    assert_equal @key.public_key, profile.public_key
    assert_equal @key.fingerprint, profile.fingerprint
    assert_redirected_to profile_path(profile)
    assert_equal "Le profil « Bob » a été ajouté.", flash[:notice]
  end

  test "create re-renders the form with errors when invalid" do
    sign_in users(:one)

    assert_no_difference "Profile.count" do
      post profiles_path, params: { profile: { name: "", public_key: "not a key" } }
    end

    assert_response :unprocessable_entity
    assert_select "#error_explanation li", 2
  end

  test "create refuses a private key and does not echo it back" do
    sign_in users(:one)

    assert_no_difference "Profile.count" do
      post profiles_path, params: { profile: { name: "Oops", public_key: @key.private_key } }
    end

    assert_response :unprocessable_entity
    assert_select "#error_explanation li", text: /ressemble à une clé privée/
  end

  test "create refuses a key already used by another profile" do
    sign_in users(:one)

    assert_no_difference "Profile.count" do
      post profiles_path, params: { profile: { name: "Alice bis", public_key: profiles(:alice).public_key } }
    end
    assert_response :unprocessable_entity
    assert_select "#error_explanation li", text: "Cette clé est déjà utilisée par un autre profil"
  end

  test "show displays the profile and its key" do
    sign_in users(:one)
    profile = profiles(:alice)

    get profile_path(profile)

    assert_response :success
    assert_select "h1", "Alice"
    assert_select "#profile-fingerprint", profile.fingerprint
    assert_select "textarea#profile-public-key", profile.public_key
    assert_select "dd", text: "alice@laptop"
    assert_select "a[href=?]", edit_profile_path(profile)
    assert_select "form[action=?][data-turbo-confirm] input[name=_method][value=delete]", profile_path(profile)
  end

  test "show handles a key without a comment" do
    sign_in users(:one)
    get profile_path(profiles(:ci))
    assert_select "dd span", text: "Aucun"
  end

  test "show, edit, update and destroy return 404 for an unknown profile" do
    # A 404 does not persist the session, so sign in again before each request.
    [ -> { get profile_path(id: 0) },
      -> { get edit_profile_path(id: 0) },
      -> { patch profile_path(id: 0), params: { profile: { name: "x" } } },
      -> { delete profile_path(id: 0) } ].each do |request|
      sign_in users(:one)
      request.call
      assert_response :not_found
    end
  end

  test "edit renders the form prefilled" do
    sign_in users(:one)
    profile = profiles(:alice)

    get edit_profile_path(profile)

    assert_response :success
    assert_select "form[action=?]", profile_path(profile) do
      assert_select "input[name='profile[name]'][value='Alice']"
      assert_select "textarea[name='profile[public_key]']", profile.public_key
      assert_select "input[type=submit][value='Enregistrer']"
    end
  end

  test "update changes the name and the key" do
    sign_in users(:one)
    profile = profiles(:alice)

    patch profile_path(profile), params: { profile: { name: "Alice Martin", public_key: @key.public_key } }

    profile.reload
    assert_equal "Alice Martin", profile.name
    assert_equal @key.fingerprint, profile.fingerprint
    assert_redirected_to profile_path(profile)
    assert_equal "Le profil « Alice Martin » a été modifié.", flash[:notice]
  end

  test "update re-renders the form with errors when invalid" do
    sign_in users(:one)
    profile = profiles(:alice)

    patch profile_path(profile), params: { profile: { name: "CI" } }

    assert_response :unprocessable_entity
    assert_select "h1", text: "Modifier « Alice »"
    assert_equal "Alice", profile.reload.name
  end

  test "destroy deletes the profile and redirects to the profiles" do
    sign_in users(:one)

    assert_difference "Profile.count", -1 do
      delete profile_path(profiles(:alice))
    end

    assert_redirected_to profiles_path
    assert_response :see_other
    assert_equal "Le profil « Alice » a été supprimé.", flash[:notice]
  end

  test "new can be prefilled from a server key, with a way back" do
    sign_in users(:one)

    get new_profile_path(public_key: @key.public_key, name: "bob", return_to: "/servers/1#server-authorized-keys")

    assert_select "p.prefilled-hint"
    assert_select "a[href=?]", "/servers/1#server-authorized-keys", text: "← Retour au serveur"
    assert_select "form[action=?]", profiles_path do
      assert_select "input[name='profile[name]'][value=bob]"
      assert_select "textarea[name='profile[public_key]']", @key.public_key
      assert_select "input[type=hidden][name=return_to][value=?]", "/servers/1#server-authorized-keys"
      assert_select "a[href=?]", "/servers/1#server-authorized-keys", text: "Annuler"
    end
  end

  test "create goes back to the given local path" do
    sign_in users(:one)

    post profiles_path, params: valid_params.merge(return_to: server_path(servers(:web), anchor: "server-authorized-keys"))

    assert_redirected_to server_path(servers(:web), anchor: "server-authorized-keys")
  end

  test "create ignores a return path to another site" do
    [ "https://evil.example", "//evil.example", "/\\evil.example", "javascript:alert(1)" ].each_with_index do |return_to, index|
      sign_in users(:one)
      post profiles_path, params: { profile: { name: "Bob #{index}", public_key: SshKeyGenerator.generate.public_key }, return_to: return_to }
      assert_redirected_to profile_path(Profile.find_by!(name: "Bob #{index}")), "#{return_to} should be ignored"
    end
  end

  test "new without a return path keeps the usual links" do
    sign_in users(:one)
    get new_profile_path(return_to: "https://evil.example")

    assert_select "a[href=?]", profiles_path, text: "← Profils"
    assert_select "input[name=return_to]", 0
  end

  test "logs the created and deleted profiles" do
    sign_in users(:one)

    post profiles_path, params: valid_params
    delete profile_path(Profile.find_by!(name: "Bob"))

    assert_equal [ "Profil « Bob » créé", "Profil « Bob » supprimé" ], Activity.order(:id).map(&:summary)
  end
end
