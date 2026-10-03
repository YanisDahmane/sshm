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

  test "lists servers sorted by name" do
    sign_in users(:one)
    get root_path

    assert_select "#servers tbody tr", Server.count
    assert_select "#servers tbody tr:first-child td:nth-child(2)", "Backup"
    assert_select "##{ActionView::RecordIdentifier.dom_id(servers(:web))}" do
      assert_select "td", text: "192.168.1.10"
      assert_select "td", text: "deploy"
    end
    assert_select "a[href=?]", new_server_path, text: "Ajouter un serveur"
  end

  test "shows an empty state when there are no servers" do
    Server.delete_all
    sign_in users(:one)
    get root_path

    assert_select "#servers", 0
    assert_select "p", text: "Aucun serveur pour le moment."
  end

  test "shows the reachability status of each server" do
    sign_in users(:one)
    get root_path

    assert_select "##{ActionView::RecordIdentifier.dom_id(servers(:web))} .server-status", text: "En ligne"
    assert_select "##{ActionView::RecordIdentifier.dom_id(servers(:db))} .server-status", text: "Injoignable"
    assert_select "##{ActionView::RecordIdentifier.dom_id(servers(:backup))} .server-status[title=?]", "Jamais vérifié", text: "Inconnu"
  end

  test "shows refresh buttons for all servers and for each server" do
    sign_in users(:one)
    get root_path

    assert_select "form[action=?][method=post][data-action*='server-ping#start']", server_pings_path
    assert_select "form[action=?][method=post][data-server-ping-badge-param=?]", server_ping_path(servers(:web)),
                  ActionView::RecordIdentifier.dom_id(servers(:web), :status) do
      assert_select "button[title=?] svg", "Actualiser le statut"
    end
  end

  test "renders badges as Stimulus targets with a checking template" do
    sign_in users(:one)
    get root_path

    assert_select "section[data-controller=server-ping]" do
      assert_select "template[data-server-ping-target=checking]"
      assert_select "##{ActionView::RecordIdentifier.dom_id(servers(:web), :status)}[data-server-ping-target=badge]"
    end
    assert_select "#flash"
  end

  test "shows an edit link for each server" do
    sign_in users(:one)
    get root_path

    Server.find_each do |server|
      assert_select "a[href=?][title=Modifier][aria-label=?] svg", edit_server_path(server), "Modifier #{server.name}"
      assert_select "td a[href=?]", server_path(server), text: server.name
    end
  end

  test "warns when no SSH key is configured" do
    SshKey.delete_all
    sign_in users(:one)
    get root_path

    assert_select "#missing-ssh-key a[href=?]", settings_path
  end

  test "does not warn when an SSH key is configured" do
    sign_in users(:one)
    get root_path

    assert_select "#missing-ssh-key", 0
  end
end
