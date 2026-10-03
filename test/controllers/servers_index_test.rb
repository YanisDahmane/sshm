require "test_helper"

class ServersIndexTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  test "requires authentication" do
    get servers_path
    assert_redirected_to new_user_session_path
  end

  test "lists servers sorted by name" do
    sign_in users(:one)
    get servers_path

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
    get servers_path

    assert_select "#servers", 0
    assert_select "p", text: "Aucun serveur pour le moment."
  end

  test "shows the reachability status of each server" do
    sign_in users(:one)
    get servers_path

    assert_select "##{ActionView::RecordIdentifier.dom_id(servers(:web))} .server-status", text: "En ligne"
    assert_select "##{ActionView::RecordIdentifier.dom_id(servers(:db))} .server-status", text: "Injoignable"
    assert_select "##{ActionView::RecordIdentifier.dom_id(servers(:backup))} .server-status[title=?]", "Jamais vérifié", text: "Inconnu"
  end

  test "shows refresh buttons for all servers and for each server" do
    sign_in users(:one)
    get servers_path

    assert_select "form[action=?][method=post][data-action*='server-ping#start']", server_pings_path
    assert_select "form[action=?][method=post][data-server-ping-badge-param=?]", server_ping_path(servers(:web)),
                  ActionView::RecordIdentifier.dom_id(servers(:web), :status) do
      assert_select "button[title=?] svg", "Actualiser le statut"
    end
  end

  test "renders badges as Stimulus targets with a checking template" do
    sign_in users(:one)
    get servers_path

    assert_select "section[data-controller=server-ping]" do
      assert_select "template[data-server-ping-target=checking]"
      assert_select "##{ActionView::RecordIdentifier.dom_id(servers(:web), :status)}[data-server-ping-target=badge]"
    end
    assert_select "#flash"
  end

  test "shows an edit link for each server" do
    sign_in users(:one)
    get servers_path

    Server.find_each do |server|
      assert_select "a[href=?][title=Modifier][aria-label=?] svg", edit_server_path(server), "Modifier #{server.name}"
      assert_select "td a[href=?]", server_path(server), text: server.name
    end
  end

  test "shows the SSH status of each server" do
    servers(:web).record_ssh_status!(true)
    servers(:db).record_ssh_status!(false)
    sign_in users(:one)

    get servers_path

    assert_select "##{ActionView::RecordIdentifier.dom_id(servers(:web))} .ssh-status", text: /OK/
    assert_select "##{ActionView::RecordIdentifier.dom_id(servers(:db))} a.ssh-status[href=?]", server_path(servers(:db)), text: /Clé refusée/
    assert_select "##{ActionView::RecordIdentifier.dom_id(servers(:backup))} .ssh-status", text: "—"
  end

  test "shows the keys without profile of scanned servers" do
    unnamed = SshKeyGenerator.generate.public_key.split(" ").first(2).join(" ")
    bob = SshKeyGenerator.generate(comment: "bob@desktop").public_key
    AccountSnapshot.record!(servers(:web), AuthorizedKeysAccount.login(servers(:web)), AuthorizedKey.parse([ unnamed, bob, ssh_keys(:main).public_key, profiles(:ci).public_key ].join("\n")))
    AccountSnapshot.record!(servers(:db), AuthorizedKeysAccount.login(servers(:db)), AuthorizedKey.parse(profiles(:alice).public_key))
    sign_in users(:one)

    get servers_path

    assert_select "##{ActionView::RecordIdentifier.dom_id(servers(:web))} a.orphan-keys[title=?]", "sans nom, bob@desktop", text: "2 clés sans profil"
    assert_select "##{ActionView::RecordIdentifier.dom_id(servers(:db))} .orphan-keys", text: "Aucune"
    assert_select "##{ActionView::RecordIdentifier.dom_id(servers(:backup))} .orphan-keys", text: "—"
  end

  test "offers to scan the keys of every server" do
    sign_in users(:one)
    get servers_path
    assert_select "form[action=?] button", server_scans_path, text: /Scanner les clés/
  end
end
