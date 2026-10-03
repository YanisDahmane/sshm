require "test_helper"

class DashboardControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  test "redirects to sign in when not authenticated" do
    get root_path
    assert_redirected_to new_user_session_path
  end

  test "shows the dashboard when authenticated" do
    sign_in users(:one)
    get root_path
    assert_response :success
    assert_select "h1", "Dashboard"
  end

  test "registers a new user and lands on the dashboard" do
    assert_difference "User.count", 1 do
      post user_registration_path, params: { user: { email: "new@example.com", password: "password123", password_confirmation: "password123" } }
    end
    assert_redirected_to root_path
  end

  test "sign in and sign up pages render" do
    get new_user_session_path
    assert_response :success
    get new_user_registration_path
    assert_response :success
  end
end
