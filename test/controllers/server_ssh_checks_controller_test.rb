require "test_helper"

class ServerSshChecksControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers
  include ActionView::RecordIdentifier
  include TcpHelpers
  include StubHelpers

  setup do
    # Point every fixture at a closed local port so no real host is contacted.
    Server.update_all(host: "127.0.0.1", port: closed_port)
  end

  def frame_id = dom_id(servers(:web), :ssh_check)

  test "requires authentication" do
    get server_ssh_check_path(servers(:web))
    assert_redirected_to new_user_session_path
  end

  test "returns 404 for an unknown server" do
    sign_in users(:one)
    get server_ssh_check_path(server_id: 0)
    assert_response :not_found
  end

  test "renders a successful check in the server's SSH frame" do
    sign_in users(:one)
    result = SshCheck::Result.new(success: true, message: "Connexion SSH réussie", details: "deploy@127.0.0.1 a répondu.")

    stub_method(SshCheck, :call, result) { get server_ssh_check_path(servers(:web)) }

    assert_response :success
    assert_select "turbo-frame##{frame_id}" do
      assert_select ".ssh-check-result[title=?]", "deploy@127.0.0.1 a répondu.", text: /Connexion OK/
      assert_select "a.health-refresh[href=?][data-turbo-prefetch=false]", server_ssh_check_path(servers(:web))
      assert_select ".ssh-check-details", 0
    end
    assert servers(:web).reload.ssh_ok
  end

  test "renders a failed check with its details" do
    sign_in users(:one)

    get server_ssh_check_path(servers(:web))

    assert_select "turbo-frame##{frame_id}" do
      assert_select ".ssh-check-result", text: /Connexion impossible/
      assert_select ".ssh-check-details", text: /127.0.0.1/
      assert_select ".ssh-setup-hint", 0
    end
    assert_equal false, servers(:web).reload.ssh_ok
  end

  test "guides the user when the SSHM key is refused" do
    sign_in users(:one)
    refused = SshCheck::Result.new(success: false, message: "Clé SSH refusée par le serveur", details: "x", reason: :key_refused)

    stub_method(SshCheck, :call, refused) { get server_ssh_check_path(servers(:web)) }

    assert_select "turbo-frame##{frame_id} .ssh-setup-hint" do
      assert_select "code", text: "deploy@127.0.0.1"
      assert_select "textarea", text: /authorized_keys/
    end
  end

  test "shows both fingerprints and lets an admin trust the new one" do
    changed = SshCheck::Result.new(success: false, message: "L'empreinte du serveur a changé", details: "x", reason: :host_key_changed,
                                   host_key: { new: "SHA256:new", known: [ "SHA256:old" ] })
    sign_in users(:one)

    stub_method(SshCheck, :call, changed) { get server_ssh_check_path(servers(:web)) }

    assert_select "turbo-frame##{frame_id} .host-key-changed" do
      assert_select ".host-key-known", "SHA256:old"
      assert_select ".host-key-new", "SHA256:new"
      assert_select "form[action=?][data-turbo-frame=_top][data-confirm-variant=danger]", server_host_key_path(servers(:web)) do
        assert_select "input[name=fingerprint][value=?]", "SHA256:new"
      end
    end
    assert_select ".ssh-setup-hint", 0
  end

  test "only admins get the button to trust a new host key" do
    changed = SshCheck::Result.new(success: false, message: "L'empreinte du serveur a changé", details: "x", reason: :host_key_changed,
                                   host_key: { new: "SHA256:new", known: [] })
    sign_in users(:operator)

    stub_method(SshCheck, :call, changed) { get server_ssh_check_path(servers(:web)) }

    assert_select ".host-key-changed" do
      assert_select ".host-key-known", "—"
      assert_select "form", 0
      assert_select "p", text: /Demandez à un administrateur/
    end
  end

  test "points to the settings and records nothing when there is no SSHM key" do
    SshKey.delete_all
    sign_in users(:one)

    get server_ssh_check_path(servers(:web))

    assert_select "turbo-frame##{frame_id} .ssh-check-result", text: /Aucune clé SSH configurée/
    assert_select "turbo-frame##{frame_id} .ssh-setup-hint a[href=?]", settings_path
    assert_nil servers(:web).reload.ssh_ok
  end
end
