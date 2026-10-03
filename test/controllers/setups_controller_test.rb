require "test_helper"

class SetupsControllerTest < ActionDispatch::IntegrationTest
  def without_users
    Invitation.delete_all
    Activity.delete_all
    User.delete_all
  end

  test "every page leads to the setup page while there is no user" do
    without_users

    [ root_path, servers_path, new_user_session_path ].each do |path|
      get path
      assert_redirected_to new_setup_path
    end
  end

  test "creates the first admin and signs them in" do
    without_users

    get new_setup_path
    assert_select "h2", "Créer le compte administrateur"

    post setup_path, params: { user: { email: "admin@example.com", password: "password123", password_confirmation: "password123" } }

    assert_redirected_to root_path
    user = User.sole
    assert user.admin?
    follow_redirect!
    assert_response :success
    assert_select "nav .user-role", "Admin"
  end

  test "re-renders the form with errors" do
    without_users

    post setup_path, params: { user: { email: "nope", password: "a", password_confirmation: "b" } }

    assert_response :unprocessable_entity
    assert_select "#error_explanation li", minimum: 2
    assert_equal 0, User.count
  end

  test "is unavailable once a user exists" do
    get new_setup_path
    assert_response :not_found

    assert_no_difference "User.count" do
      post setup_path, params: { user: { email: "intruder@example.com", password: "password123", password_confirmation: "password123" } }
    end
    assert_response :not_found
  end
end
