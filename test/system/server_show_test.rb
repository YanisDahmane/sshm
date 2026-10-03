require "application_system_test_case"

class ServerShowTest < ApplicationSystemTestCase
  include Devise::Test::IntegrationHelpers
  include TcpHelpers
  include StubHelpers
  include ActionView::RecordIdentifier

  setup do
    Server.update_all(host: "127.0.0.1", port: closed_port)
    sign_in users(:one)
  end

  test "opening a server from the servers page" do
    visit servers_path
    click_on "Web"

    assert_selector "h1", text: "Web"
    assert_selector "#server-health .server-status"
  end

  test "the port and SSH access are checked on display and can be checked again" do
    visit server_path(servers(:web))
    execute_script("window.noFullReload = true")

    within("#server-health") do
      assert_selector ".server-status", text: "Injoignable"
      assert_selector ".ssh-check-result", text: "Connexion impossible"
      assert_selector ".ssh-check-details"
      assert_no_selector ".health-checking"

      find("a[title='Revérifier le port']").click
      assert_selector ".server-status", text: "Injoignable"
      find("a[title='Retester la connexion SSH']").click
      assert_selector ".ssh-check-result", text: "Connexion impossible"
    end
    assert evaluate_script("window.noFullReload")
    assert_selector "h1", text: "Web"
  end


  test "authorized keys load lazily and can be reloaded" do
    visit server_path(servers(:web))

    within("#server-authorized-keys") do
      assert_selector ".authorized-keys-error", text: "Connexion impossible"
      click_on "Recharger les clés"
      assert_selector ".authorized-keys-error", text: "Connexion impossible"
    end
    assert_selector "h1", text: "Web"
  end

  test "deleting a server from its page" do
    visit server_path(servers(:backup))

    dismiss_app_confirm { first("button.delete-server").click }
    assert_selector "h1", text: "Backup"

    accept_app_confirm("Supprimer le serveur") { first("button.delete-server").click }

    assert_selector "h1", text: "Serveurs"
    assert_text "Le serveur « Backup » a été supprimé de SSHM."
    assert_no_selector "#servers", text: "Backup"

    visit activities_path
    assert_selector "li.activity", text: "Serveur « Backup » supprimé de SSHM"
  end

  test "opening and closing the details of a key" do
    stub_method_until_teardown(AuthorizedKeysReader, :call, AuthorizedKeysReader::Result.new(keys: AuthorizedKey.parse(profiles(:alice).public_key), error_title: nil, error_details: nil))
    stub_method_until_teardown(ServerAccountsReader, :call, ->(server, **) { ServerAccountsReader::Result.new(accounts: [ AuthorizedKeysAccount.login(server) ], error_title: nil, error_details: nil) })
    visit server_path(servers(:web))

    within("#server-authorized-keys") do
      assert_selector "li.authorized-key", text: "alice@laptop"
      assert_no_text profiles(:alice).fingerprint
      find("button[title='Détails de la clé']").click
    end

    within("dialog.key-details[open]") do
      assert_text profiles(:alice).fingerprint
      find("button[aria-label=Fermer]").click
    end
    assert_no_selector "dialog.key-details[open]"

    find("#server-authorized-keys button[title='Détails de la clé']").click
    find("dialog.key-details[open]").send_keys(:escape)
    assert_no_selector "dialog.key-details[open]"
  end
end
