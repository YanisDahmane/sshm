require "test_helper"

class ServerSshChecksControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers
  include ActionView::RecordIdentifier
  include TcpHelpers

  setup do
    # Point every fixture at a closed local port so no real host is contacted.
    Server.update_all(host: "127.0.0.1", port: closed_port)
  end

  test "requires authentication" do
    post server_ssh_check_path(servers(:web))
    assert_redirected_to new_user_session_path
  end

  test "returns 404 for an unknown server" do
    sign_in users(:one)
    post server_ssh_check_path(server_id: 0), as: :turbo_stream
    assert_response :not_found
  end

  test "renders a failed check in place over Turbo Stream" do
    sign_in users(:one)

    post server_ssh_check_path(servers(:web)), as: :turbo_stream

    assert_response :success
    assert_turbo_stream action: :update, target: dom_id(servers(:web), :ssh_check) do
      assert_select ".ssh-check-result.bg-red-50", text: /Connexion impossible/
    end
  end

  test "explains a missing SSH key over Turbo Stream" do
    SshKey.delete_all
    sign_in users(:one)

    post server_ssh_check_path(servers(:web)), as: :turbo_stream

    assert_turbo_stream action: :update, target: dom_id(servers(:web), :ssh_check) do
      assert_select ".ssh-check-result", text: /Aucune clé SSH configurée/
    end
  end

  test "renders a successful check in place over Turbo Stream" do
    sign_in users(:one)
    result = SshCheck::Result.new(success: true, message: "Connexion SSH réussie", details: "deploy@127.0.0.1 a répondu.")

    with_ssh_check_result(result) do
      post server_ssh_check_path(servers(:web)), as: :turbo_stream
    end

    assert_turbo_stream action: :update, target: dom_id(servers(:web), :ssh_check) do
      assert_select ".ssh-check-result.bg-emerald-50", text: /Connexion SSH réussie/
    end
  end

  test "the HTML fallback redirects to the server with the result as a flash" do
    sign_in users(:one)

    post server_ssh_check_path(servers(:web))

    assert_redirected_to server_path(servers(:web))
    assert_match "Connexion impossible", flash[:alert]
  end

  private

  # Replaces SshCheck.call for the duration of the block (no real SSH server in tests).
  def with_ssh_check_result(result)
    original = SshCheck.method(:call)
    SshCheck.define_singleton_method(:call) { |*| result }
    yield
  ensure
    SshCheck.define_singleton_method(:call, original)
  end
end
