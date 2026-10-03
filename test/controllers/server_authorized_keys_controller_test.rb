require "test_helper"

class ServerAuthorizedKeysControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers
  include ActionView::RecordIdentifier
  include StubHelpers
  include TcpHelpers

  def frame_id = dom_id(servers(:web), :authorized_keys)

  def keys_result(*lines)
    AuthorizedKeysReader::Result.new(keys: AuthorizedKey.parse(lines.join("\n")), error_title: nil, error_details: nil)
  end

  test "requires authentication" do
    get server_authorized_keys_path(servers(:web))
    assert_redirected_to new_user_session_path
  end

  test "returns 404 for an unknown server" do
    sign_in users(:one)
    get server_authorized_keys_path(server_id: 0)
    assert_response :not_found
  end

  test "lists keys with known, unknown and master badges" do
    sign_in users(:one)
    other = SshKeyGenerator.generate
    unnamed = other.public_key.split(" ").first(2).join(" ")
    named = SshKeyGenerator.generate(comment: "alice@laptop").public_key

    stub_method(AuthorizedKeysReader, :call, keys_result(ssh_keys(:main).public_key, unnamed, named)) do
      get server_authorized_keys_path(servers(:web))
    end

    assert_response :success
    assert_select "turbo-frame##{frame_id}" do
      assert_select "p", text: /3 clés/
      assert_select "li.authorized-key", 3
      assert_select "li.authorized-key:nth-child(1)" do
        assert_select ".key-name", "sshm-fixture"
        assert_select ".key-badge", text: "Connue"
        assert_select ".key-master", text: "Master"
      end
      assert_select "li.authorized-key:nth-child(2)" do
        assert_select ".key-name", "Sans nom"
        assert_select ".key-badge", text: "Inconnue"
        assert_select ".key-master", 0
        assert_select "p", text: /#{Regexp.escape(other.fingerprint)}/
      end
      assert_select "li.authorized-key:nth-child(3)" do
        assert_select ".key-name", "alice@laptop"
        assert_select ".key-badge", text: "Connue"
        assert_select ".key-master", 0
      end
      assert_select "a[href=?][title=?]", server_authorized_keys_path(servers(:web)), "Recharger les clés"
    end
  end

  test "flags the master key even if renamed on the server" do
    sign_in users(:one)
    renamed = ssh_keys(:main).public_key.split(" ").first(2).join(" ")

    stub_method(AuthorizedKeysReader, :call, keys_result(renamed)) do
      get server_authorized_keys_path(servers(:web))
    end

    assert_select ".key-badge", text: "Inconnue"
    assert_select ".key-master", text: "Master"
  end

  test "shows options when a key has some" do
    sign_in users(:one)
    key = SshKeyGenerator.generate(comment: "ci").public_key

    stub_method(AuthorizedKeysReader, :call, keys_result(%(from="10.0.0.1",no-pty #{key}))) do
      get server_authorized_keys_path(servers(:web))
    end

    assert_select "p[title=Options]", text: %(options : from="10.0.0.1",no-pty)
  end

  test "shows an empty state when there are no keys" do
    sign_in users(:one)

    stub_method(AuthorizedKeysReader, :call, keys_result) do
      get server_authorized_keys_path(servers(:web))
    end

    assert_select "turbo-frame##{frame_id} p", text: "Aucune clé autorisée sur ce serveur."
  end

  test "shows the error when the keys cannot be read" do
    Server.update_all(host: "127.0.0.1", port: closed_port)
    sign_in users(:one)

    get server_authorized_keys_path(servers(:web))

    assert_select "turbo-frame##{frame_id} .authorized-keys-error", text: /Connexion impossible/
    assert_select "li.authorized-key", 0
  end

  test "the server page lazy-loads the frame" do
    sign_in users(:one)

    get server_path(servers(:web))

    assert_select "#server-authorized-keys turbo-frame##{frame_id}[loading=lazy][src=?]", server_authorized_keys_path(servers(:web))
  end

  test "offers to authorize the profiles that are not on the server yet" do
    sign_in users(:one)

    stub_method(AuthorizedKeysReader, :call, keys_result(profiles(:ci).public_key)) do
      get server_authorized_keys_path(servers(:web))
    end

    assert_select "form#authorize-profile[action=?][data-controller=quiet-submit]", server_authorizations_path(servers(:web)) do
      assert_select "select[name=profile_id] option", 1
      assert_select "option[value=?]", profiles(:alice).id.to_s, text: "Alice"
      assert_select "button[type=submit]", text: /Autoriser/
    end
  end

  test "tags keys that belong to a profile, whatever their comment" do
    sign_in users(:one)
    type, blob = profiles(:alice).public_key.split(" ")

    stub_method(AuthorizedKeysReader, :call, keys_result("#{type} #{blob} renamed")) do
      get server_authorized_keys_path(servers(:web))
    end

    assert_select "li.authorized-key a.key-profile[href=?][data-turbo-frame=_top]", profile_path(profiles(:alice)), text: /Profil : Alice/
  end

  test "says when every profile is already authorized" do
    sign_in users(:one)

    stub_method(AuthorizedKeysReader, :call, keys_result(profiles(:alice).public_key, profiles(:ci).public_key)) do
      get server_authorized_keys_path(servers(:web))
    end

    assert_select "form#authorize-profile", 0
    assert_select "#all-profiles-authorized"
  end

  test "invites to create a profile when there is none" do
    Profile.delete_all
    sign_in users(:one)

    stub_method(AuthorizedKeysReader, :call, keys_result) do
      get server_authorized_keys_path(servers(:web))
    end

    assert_select "form#authorize-profile", 0
    assert_select "a[href=?][data-turbo-frame=_top]", new_profile_path
  end

  test "does not offer to authorize when the keys cannot be read" do
    Server.update_all(host: "127.0.0.1", port: closed_port)
    sign_in users(:one)

    get server_authorized_keys_path(servers(:web))

    assert_select "form#authorize-profile", 0
  end
end
