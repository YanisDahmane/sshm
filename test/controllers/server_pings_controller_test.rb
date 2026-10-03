require "test_helper"

class ServerPingsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers
  include TcpHelpers
  include ActionView::RecordIdentifier

  setup do
    # Point every fixture at a closed local port so no real host is contacted.
    Server.update_all(host: "127.0.0.1", port: closed_port)
  end

  test "requires authentication to ping one server" do
    post server_ping_path(servers(:web))
    assert_redirected_to new_user_session_path
    assert_equal true, servers(:web).reload.reachable
  end

  test "requires authentication to ping all servers" do
    post server_pings_path
    assert_redirected_to new_user_session_path
  end

  test "pings one server and reports it online" do
    sign_in users(:one)

    with_open_port do |port|
      servers(:db).update_columns(port: port)
      post server_ping_path(servers(:db))
    end

    assert_redirected_to root_path
    assert_equal "« Database » est en ligne.", flash[:notice]
    assert servers(:db).reload.reachable
  end

  test "pings one server and reports it unreachable" do
    sign_in users(:one)

    post server_ping_path(servers(:web))

    assert_redirected_to root_path
    assert_equal "« Web » est injoignable.", flash[:notice]
    assert_equal false, servers(:web).reload.reachable
  end

  test "pinging one server leaves the others untouched" do
    sign_in users(:one)

    assert_no_changes -> { servers(:backup).reload.last_checked_at } do
      post server_ping_path(servers(:web))
    end
  end

  test "returns 404 for an unknown server" do
    sign_in users(:one)
    post server_ping_path(server_id: 0)
    assert_response :not_found
  end

  test "pings all servers and summarizes the results" do
    sign_in users(:one)

    with_open_port do |port|
      servers(:backup).update_columns(port: port)
      post server_pings_path
    end

    assert_redirected_to root_path
    assert_equal "Statuts actualisés : 1 en ligne, 2 injoignable(s).", flash[:notice]
    assert servers(:backup).reload.reachable
    assert_equal false, servers(:web).reload.reachable
    assert Server.where(last_checked_at: nil).none?
  end

  test "pinging one server over Turbo Stream replaces its badge and the flash" do
    sign_in users(:one)

    with_open_port do |port|
      servers(:db).update_columns(port: port)
      post server_ping_path(servers(:db)), as: :turbo_stream
    end

    assert_response :success
    assert_equal "text/vnd.turbo-stream.html", response.media_type
    assert_turbo_stream action: :replace, target: dom_id(servers(:db), :status) do
      assert_select ".server-status", text: "En ligne"
    end
    assert_turbo_stream action: :update, target: "flash" do
      assert_select "div", text: "« Database » est en ligne."
    end
    assert_no_turbo_stream action: :replace, target: dom_id(servers(:web), :status)
  end

  test "pinging all servers over Turbo Stream replaces every badge" do
    sign_in users(:one)

    post server_pings_path, as: :turbo_stream

    assert_response :success
    Server.find_each do |server|
      assert_turbo_stream action: :replace, target: dom_id(server, :status) do
        assert_select ".server-status", text: "Injoignable"
      end
    end
    assert_turbo_stream action: :update, target: "flash" do
      assert_select "div", text: "Statuts actualisés : 0 en ligne, 3 injoignable(s)."
    end
  end

  test "the flash from a Turbo Stream ping does not leak into the next page" do
    sign_in users(:one)

    post server_ping_path(servers(:web)), as: :turbo_stream
    get root_path

    assert_select "#flash div", 0
  end

  test "the HTML fallback redirects back to the referring page" do
    sign_in users(:one)

    post server_ping_path(servers(:web)), headers: { "HTTP_REFERER" => server_url(servers(:web)) }

    assert_redirected_to server_url(servers(:web))
  end

  test "show pings the server and renders its reachability frame" do
    sign_in users(:one)

    with_open_port do |port|
      servers(:db).update_columns(port: port)
      get server_ping_path(servers(:db))
    end

    assert_response :success
    assert_select "turbo-frame##{dom_id(servers(:db), :reachability)}" do
      assert_select ".server-status", text: "En ligne"
      assert_select "time[data-controller=relative-time]"
      assert_select "a.health-refresh[href=?][data-turbo-prefetch=false]", server_ping_path(servers(:db))
    end
    assert servers(:db).reload.reachable
  end

  test "show requires authentication" do
    get server_ping_path(servers(:web))
    assert_redirected_to new_user_session_path
  end
end
