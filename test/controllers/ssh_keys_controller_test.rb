require "test_helper"

class SshKeysControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  test "requires authentication" do
    assert_no_changes -> { SshKey.current.public_key } do
      post ssh_key_path
    end
    assert_redirected_to new_user_session_path
  end

  test "generates the first key" do
    SshKey.delete_all
    sign_in users(:one)

    assert_difference "SshKey.count", 1 do
      post ssh_key_path
    end

    assert_redirected_to settings_path
    assert_equal "Clé SSH générée. Ajoutez la clé publique sur vos serveurs.", flash[:notice]
  end

  test "regenerates and replaces the existing key" do
    sign_in users(:one)
    old_public_key = ssh_keys(:main).public_key

    assert_no_difference "SshKey.count" do
      post ssh_key_path
    end

    assert_not_equal old_public_key, SshKey.current.public_key
    assert_redirected_to settings_path
    assert_equal "Nouvelle clé SSH générée. Remplacez l'ancienne clé publique sur vos serveurs.", flash[:notice]
  end

  test "logs the generation with its author" do
    sign_in users(:one)

    post ssh_key_path

    activity = Activity.of_kind(:ssh_key_generated).sole
    assert_equal users(:one), activity.user
    assert_equal "Clé SSHM régénérée", activity.summary
  end
end
