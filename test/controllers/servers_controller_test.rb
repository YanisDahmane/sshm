require "test_helper"

class ServersControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers
  include ActionView::RecordIdentifier

  def valid_params
    { server: { name: "Staging", host: "staging.example.com", port: 2222, username: "deploy" } }
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
      assert_select "input[name='server[password]']", 0
    end
  end

  test "create saves the server and redirects to the dashboard" do
    sign_in users(:one)

    assert_difference "Server.count", 1 do
      post servers_path, params: valid_params
    end

    server = Server.find_by!(name: "Staging")
    assert_equal [ "staging.example.com", 2222, "deploy" ], [ server.host, server.port, server.username ]
    assert_redirected_to root_path
    follow_redirect!
    assert_select "div", text: "Le serveur « Staging » a été ajouté."
  end

  test "create re-renders the form with errors when invalid" do
    sign_in users(:one)

    assert_no_difference "Server.count" do
      post servers_path, params: { server: { name: "", host: "not a host", port: 0, username: "" } }
    end

    assert_response :unprocessable_entity
    assert_select "#error_explanation li", minimum: 4
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

  test "edit and update redirect to sign in when not authenticated" do
    get edit_server_path(servers(:web))
    assert_redirected_to new_user_session_path

    patch server_path(servers(:web)), params: { server: { name: "Hacked" } }
    assert_redirected_to new_user_session_path
    assert_equal "Web", servers(:web).reload.name
  end

  test "edit renders the form prefilled" do
    sign_in users(:one)
    get edit_server_path(servers(:web))

    assert_response :success
    assert_select "form[action=?]", server_path(servers(:web)) do
      assert_select "input[name='server[name]'][value='Web']"
      assert_select "input[name='server[host]'][value='192.168.1.10']"
      assert_select "input[name='server[port]'][value='22']"
      assert_select "input[name='server[username]'][value='deploy']"
      assert_select "input[type=submit][value='Enregistrer']"
    end
  end

  test "edit returns 404 for an unknown server" do
    sign_in users(:one)
    get edit_server_path(id: 0)
    assert_response :not_found
  end

  test "update changes the server and redirects to the dashboard" do
    sign_in users(:one)

    patch server_path(servers(:web)), params: { server: { name: "Web prod", host: "web.example.com", port: 2200, username: "ops" } }

    server = servers(:web).reload
    assert_equal [ "Web prod", "web.example.com", 2200, "ops" ], [ server.name, server.host, server.port, server.username ]
    assert_redirected_to server_path(server)
    assert_equal "Le serveur « Web prod » a été modifié.", flash[:notice]
  end

  test "update ignores a password param" do
    sign_in users(:one)

    patch server_path(servers(:web)), params: { server: { name: "Web 2", password: "ignored" } }

    assert_redirected_to server_path(servers(:web))
    assert_equal "Web 2", servers(:web).reload.name
    assert_not servers(:web).has_attribute?(:password)
  end

  test "update re-renders the form with errors when invalid" do
    sign_in users(:one)

    patch server_path(servers(:web)), params: { server: { name: "", host: "not a host" } }

    assert_response :unprocessable_entity
    assert_select "#error_explanation li", minimum: 2
    assert_select "h1", text: "Modifier « Web »"
    assert_equal "Web", servers(:web).reload.name
  end

  test "update rejects a name already used by another server" do
    sign_in users(:one)

    patch server_path(servers(:web)), params: { server: { name: "database" } }

    assert_response :unprocessable_entity
    assert_equal "Web", servers(:web).reload.name
  end

  test "show redirects to sign in when not authenticated" do
    get server_path(servers(:web))
    assert_redirected_to new_user_session_path
  end

  test "show displays the server name, its status and the SSH check" do
    sign_in users(:one)
    server = servers(:web)

    get server_path(server)

    assert_response :success
    assert_select "h1", "Web"
    assert_select "p", text: "deploy@192.168.1.10:22"
    assert_select "a[href=?]", edit_server_path(server)
    assert_select "[data-controller=server-ping]" do
      assert_select "template[data-server-ping-target=checking]"
      assert_select "#server-status ##{dom_id(server, :status)}", text: "En ligne"
      assert_select "#server-status form[action=?][data-server-ping-badge-param=?]", server_ping_path(server), dom_id(server, :status)
    end
    assert_select "#server-ssh form[action=?][data-controller=quiet-submit] button", server_ssh_check_path(server), text: /Tester la connexion SSH/
    assert_select "#server-ssh ##{dom_id(server, :ssh_check)}:empty"
  end

  test "show returns 404 for an unknown server" do
    sign_in users(:one)
    get server_path(id: 0)
    assert_response :not_found
  end
end
