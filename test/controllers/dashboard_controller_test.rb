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

  test "lists servers sorted by name without exposing passwords" do
    sign_in users(:one)
    get root_path

    assert_select "#servers tbody tr", Server.count
    assert_select "#servers tbody tr:first-child td:first-child", "Backup"
    assert_select "##{ActionView::RecordIdentifier.dom_id(servers(:web))}" do
      assert_select "td", text: "192.168.1.10"
      assert_select "td", text: "deploy"
      assert_select "td", text: "Défini"
    end
    assert_select "##{ActionView::RecordIdentifier.dom_id(servers(:backup))} td", text: "—"
    assert_no_match "s3cret", response.body
    assert_select "a[href=?]", new_server_path, text: "Ajouter un serveur"
  end

  test "shows an empty state when there are no servers" do
    Server.delete_all
    sign_in users(:one)
    get root_path

    assert_select "#servers", 0
    assert_select "p", text: "Aucun serveur pour le moment."
  end
end
