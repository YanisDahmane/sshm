require "test_helper"

class ServersControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  def valid_params
    { server: { name: "Staging", host: "staging.example.com", port: 2222, username: "deploy", password: "pa55" } }
  end

  test "new redirects to sign in when not authenticated" do
    get new_server_path
    assert_redirected_to new_user_session_path
  end

  test "create redirects to sign in when not authenticated" do
    assert_no_difference "Server.count" do
      post servers_path, params: valid_params
    end
    assert_redirected_to new_user_session_path
  end

  test "new renders the form with port 22 by default" do
    sign_in users(:one)
    get new_server_path

    assert_response :success
    assert_select "form[action=?]", servers_path do
      assert_select "input[name='server[name]']"
      assert_select "input[name='server[host]']"
      assert_select "input[name='server[port]'][value='22']"
      assert_select "input[name='server[username]']"
      assert_select "input[type=password][name='server[password]']"
    end
  end

  test "create saves the server and redirects to the dashboard" do
    sign_in users(:one)

    assert_difference "Server.count", 1 do
      post servers_path, params: valid_params
    end

    server = Server.find_by!(name: "Staging")
    assert_equal [ "staging.example.com", 2222, "deploy", "pa55" ], [ server.host, server.port, server.username, server.password ]
    assert_redirected_to root_path
    follow_redirect!
    assert_select "div", text: "Le serveur « Staging » a été ajouté."
  end

  test "create re-renders the form with errors when invalid" do
    sign_in users(:one)

    assert_no_difference "Server.count" do
      post servers_path, params: { server: { name: "", host: "not a host", port: 0, username: "", password: "secret" } }
    end

    assert_response :unprocessable_entity
    assert_select "#error_explanation li", minimum: 4
    assert_select "input[name='server[password]'][value]", 0
  end

  test "create rejects a duplicate name" do
    sign_in users(:one)

    assert_no_difference "Server.count" do
      post servers_path, params: { server: valid_params[:server].merge(name: "web") }
    end
    assert_response :unprocessable_entity
  end

  test "create rejects requests without server params" do
    sign_in users(:one)
    post servers_path, params: {}
    assert_response :bad_request
  end
end
