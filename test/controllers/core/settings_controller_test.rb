require "test_helper"

class SettingsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  test "requires authentication" do
    get settings_path
    assert_redirected_to new_user_session_path
  end

  test "shows the public key, its fingerprint and the install command" do
    sign_in users(:one)
    key = ssh_keys(:main)

    get settings_path

    assert_response :success
    assert_select "#ssh-key-fingerprint", key.fingerprint
    assert_select "textarea#ssh-public-key", key.public_key
    assert_select "textarea#ssh-install-command", text: /echo '#{Regexp.escape(key.public_key)}' >> ~\/.ssh\/authorized_keys/
    assert_select "[data-controller=clipboard] button[data-action='clipboard#copy']", 2
    assert_select "form[action=?] button[data-turbo-confirm]", ssh_key_path, text: "Régénérer la clé"
  end

  test "never renders the private key" do
    sign_in users(:one)

    get settings_path

    assert_no_match "PRIVATE KEY", response.body
    assert_no_match ssh_keys(:main).private_key.lines[1].strip, response.body
  end

  test "offers to generate a key when there is none" do
    SshKey.delete_all
    sign_in users(:one)

    get settings_path

    assert_select "#ssh-public-key", 0
    assert_select "form[action=?] button", ssh_key_path, text: "Générer une clé SSH"
  end

  test "is linked from the navbar" do
    sign_in users(:one)
    get root_path
    assert_select "nav a[href=?][title=Paramètres] svg", settings_path
  end
end
