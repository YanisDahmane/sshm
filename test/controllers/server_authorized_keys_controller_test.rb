require "test_helper"

class ServerAuthorizedKeysControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers
  include ActionView::RecordIdentifier
  include StubHelpers
  include TcpHelpers

  def frame_id = dom_id(servers(:web), :authorized_keys)

  setup do
    # Server accounts discovered over SSH: the login user (deploy) and root.
    accounts = ->(server, **) { ServerAccountsReader::Result.new(accounts: [ AuthorizedKeysAccount.login(server), AuthorizedKeysAccount.for(server, "root") ], error_title: nil, error_details: nil) }
    stub_method_until_teardown(ServerAccountsReader, :call, accounts)
  end

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
      assert_select "a[href=?][title=?]", server_authorized_keys_path(servers(:web), account: "deploy"), "Recharger les clés"
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

    assert_select "form.authorize-profile[action=?][data-controller=quiet-submit]", server_authorizations_path(servers(:web)) do
      assert_select "input[type=hidden][name=account][value=deploy]"
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

    assert_select "form.authorize-profile", 0
    assert_select ".all-profiles-authorized"
  end

  test "invites to create a profile when there is none" do
    Profile.delete_all
    sign_in users(:one)

    stub_method(AuthorizedKeysReader, :call, keys_result) do
      get server_authorized_keys_path(servers(:web))
    end

    assert_select "form.authorize-profile", 0
    assert_select "a[href=?][data-turbo-frame=_top]", new_profile_path
  end

  test "does not offer to authorize when the keys cannot be read" do
    Server.update_all(host: "127.0.0.1", port: closed_port)
    sign_in users(:one)

    get server_authorized_keys_path(servers(:web))

    assert_select "form.authorize-profile", 0
  end

  test "offers to delete every key except the SSHM key" do
    sign_in users(:one)
    named = SshKeyGenerator.generate(comment: "alice@laptop").public_key

    stub_method(AuthorizedKeysReader, :call, keys_result(ssh_keys(:main).public_key, named)) do
      get server_authorized_keys_path(servers(:web))
    end

    assert_select "li.authorized-key:nth-child(1) form", 0
    assert_select "li.authorized-key:nth-child(2) form[action=?][data-turbo-confirm][data-turbo-frame=_top]", server_authorized_key_path(servers(:web)) do
      assert_select "input[name=_method][value=delete]"
      assert_select "input[name=key][value=?]", named.split(" ")[1]
      assert_select "input[name=name][value=?]", "alice@laptop"
      assert_select "button[title=?] svg", "Supprimer la clé"
    end
  end

  test "destroy requires authentication" do
    delete server_authorized_key_path(servers(:web)), params: { key: "AAAA" }
    assert_redirected_to new_user_session_path
  end

  test "destroy requires a key" do
    sign_in users(:one)
    delete server_authorized_key_path(servers(:web))
    assert_response :bad_request
  end

  test "destroy removes the key and reloads the list over Turbo Stream" do
    sign_in users(:one)
    removed = AuthorizedKeyRemoval::Result.new(status: :removed, error_title: nil, error_details: nil)

    stub_method(AuthorizedKeyRemoval, :call, removed) do
      delete server_authorized_key_path(servers(:web)), params: { key: "AAAA", name: "alice@laptop" }, as: :turbo_stream
    end

    assert_response :success
    assert_turbo_stream action: :replace, target: frame_id do
      assert_select "turbo-frame[loading=eager][src=?]", server_authorized_keys_path(servers(:web), account: "deploy")
    end
    assert_turbo_stream action: :update, target: "flash" do
      assert_select "div", text: "La clé « alice@laptop » a été supprimée de « Web » pour deploy."
    end
  end

  test "destroy reports a key that was already gone, unnamed" do
    sign_in users(:one)
    absent = AuthorizedKeyRemoval::Result.new(status: :absent, error_title: nil, error_details: nil)

    stub_method(AuthorizedKeyRemoval, :call, absent) do
      delete server_authorized_key_path(servers(:web)), params: { key: "AAAA" }, as: :turbo_stream
    end

    assert_turbo_stream action: :update, target: "flash" do
      assert_select "div", text: "La clé « sans nom » n'était plus présente sur « Web » pour deploy."
    end
  end

  test "destroy refuses the SSHM key" do
    sign_in users(:one)

    delete server_authorized_key_path(servers(:web)), params: { key: ssh_keys(:main).public_key.split(" ")[1], name: "sshm" }, as: :turbo_stream

    assert_turbo_stream action: :update, target: "flash" do
      assert_select "div.bg-red-50", text: /Suppression interdite/
    end
  end

  test "destroy HTML fallback redirects to the server page" do
    sign_in users(:one)
    removed = AuthorizedKeyRemoval::Result.new(status: :removed, error_title: nil, error_details: nil)

    stub_method(AuthorizedKeyRemoval, :call, removed) do
      delete server_authorized_key_path(servers(:web)), params: { key: "AAAA", name: "bob" }
    end

    assert_redirected_to server_path(servers(:web))
    assert_response :see_other
  end

  test "lists root's keys with account-specific frame, form and delete buttons" do
    sign_in users(:one)
    named = SshKeyGenerator.generate(comment: "ops").public_key
    accounts = []
    reader = lambda do |_server, account:, **|
      accounts << account
      keys_result(named)
    end

    stub_method(AuthorizedKeysReader, :call, reader) do
      get server_authorized_keys_path(servers(:web), account: "root")
    end

    assert_equal [ "root" ], accounts.map(&:name)
    assert_select "turbo-frame##{frame_id}" do
      assert_select "code", "~root/.ssh/authorized_keys"
      assert_select "a[href=?]", server_authorized_keys_path(servers(:web), account: "root")
      assert_select "form.authorize-profile input[name=account][value=root]"
      assert_select "label", text: "Autoriser un profil pour root"
      assert_select "li.authorized-key form input[name=account][value=root]"
    end
  end

  test "rejects an invalid account name" do
    [ "../etc", "root; rm -rf /", "~bob", "" * 1 + "-x" ].each do |account|
      sign_in users(:one)
      get server_authorized_keys_path(servers(:web), account: account)
      assert_response :bad_request, "#{account.inspect} should be rejected"
    end
  end

  test "destroy targets the requested account" do
    sign_in users(:one)
    accounts = []
    remover = lambda do |_server, _blob, account:, **|
      accounts << account
      AuthorizedKeyRemoval::Result.new(status: :removed, error_title: nil, error_details: nil)
    end

    stub_method(AuthorizedKeyRemoval, :call, remover) do
      delete server_authorized_key_path(servers(:web)), params: { key: "AAAA", name: "ops", account: "root" }, as: :turbo_stream
    end

    assert_equal [ "root" ], accounts.map(&:name)
    assert_turbo_stream action: :replace, target: frame_id do
      assert_select "turbo-frame[src=?]", server_authorized_keys_path(servers(:web), account: "root")
    end
    assert_turbo_stream action: :update, target: "flash" do
      assert_select "div", text: "La clé « ops » a été supprimée de « Web » pour root."
    end
  end

  test "shows a tab per server account, the current one highlighted" do
    sign_in users(:one)

    stub_method(AuthorizedKeysReader, :call, keys_result) do
      get server_authorized_keys_path(servers(:web), account: "root")
    end

    assert_select "nav.account-tabs a.account-tab", 2
    assert_select "a.account-tab[href=?]", server_authorized_keys_path(servers(:web), account: "deploy"), text: /deploy\s+connexion/
    assert_select "a.account-tab[href=?][aria-current=page]", server_authorized_keys_path(servers(:web), account: "root"), text: /root\s+via sudo/
  end

  test "keeps a requested account in the tabs even if it was not discovered" do
    sign_in users(:one)

    stub_method(AuthorizedKeysReader, :call, keys_result) do
      get server_authorized_keys_path(servers(:web), account: "bob")
    end

    assert_select "a.account-tab[aria-current=page]", text: /bob\s+via sudo/
    assert_select "code", "~bob/.ssh/authorized_keys"
  end

  test "defaults to the login user" do
    sign_in users(:one)
    accounts = []
    reader = lambda do |_server, account:, **|
      accounts << account
      keys_result
    end

    stub_method(AuthorizedKeysReader, :call, reader) do
      get server_authorized_keys_path(servers(:web))
    end

    assert_equal [ "deploy" ], accounts.map(&:unix_user)
    assert_select "a.account-tab[aria-current=page]", text: /deploy/
  end
end
