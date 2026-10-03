require "application_system_test_case"

class UiTest < ApplicationSystemTestCase
  include Devise::Test::IntegrationHelpers
  include StubHelpers
  include ActionView::RecordIdentifier

  setup do
    sign_in users(:one)
  end

  test "toasts can be closed and disappear by themselves" do
    visit servers_path
    click_on "Scanner les clés"

    assert_selector "#flash .toast", text: "Scan des clés lancé"
    find("#flash .toast button[aria-label=Fermer]").click
    assert_no_selector "#flash .toast"

    click_on "Scanner les clés"
    assert_selector "#flash .toast"
    execute_script("document.querySelector('#flash [data-controller=toast]').dispatchEvent(new MouseEvent('mouseleave'))")
    assert_no_selector "#flash .toast", wait: 8
  end

  test "the confirm dialog uses the action's label and colour, and Escape cancels" do
    visit profile_path(profiles(:alice))
    click_on "Supprimer"

    within("#confirm-dialog[open]") do
      assert_text "Le profil « Alice » sera supprimé."
      assert_selector "button[data-confirm-accept][data-variant=danger]", text: "Supprimer"
    end
    find("#confirm-dialog[open]").send_keys(:escape)
    assert_no_selector "#confirm-dialog[open]"
    assert_selector "h1", text: "Alice"
  end

  test "quick search finds a server and opens it with the keyboard" do
    visit root_path
    find("body").send_keys([ :control, "k" ])

    within("#command-palette[open]") do
      find("input[type=search]").fill_in(with: "dat")
      assert_selector ".command-palette-item", count: 1, text: "Database"
      find("input[type=search]").send_keys(:enter)
    end

    assert_selector "h1", text: "Database"
    assert_no_selector "#command-palette[open]"
  end

  test "quick search ignores accents and lists pages" do
    visit root_path
    find(".command-palette-button").click

    within("#command-palette[open]") do
      find("input[type=search]").fill_in(with: "parametres")
      assert_selector ".command-palette-item[aria-selected=true]", text: "Paramètres"
      find("input[type=search]").fill_in(with: "zzz")
      assert_text "Aucun résultat."
    end
  end

  test "authorizing a profile on several servers at once" do
    granted = []
    granter = lambda do |server, _profile, account:, **|
      granted << [ server.name, account.unix_user ]
      ProfileAuthorization::Result.new(status: :added, error_title: nil, error_details: nil)
    end
    reader = ->(*, **) { AuthorizedKeysReader::Result.new(keys: AuthorizedKey.parse(profiles(:alice).public_key), error_title: nil, error_details: nil) }

    stub_method(AccessGrant, :call, granter) do
      stub_method(AuthorizedKeysReader, :call, reader) do
        visit profile_path(profiles(:alice))
        within("#bulk-authorize") do
          click_on "Tout cocher / décocher"
          uncheck "Backup"
          fill_in "Compte", with: "debian"
          click_on "Autoriser"

          assert_selector "li.bulk-result.is-success", count: 2
        end
        assert_selector "#profile-accesses li.profile-access", count: 2
      end
    end

    assert_equal [ [ "Database", "debian" ], [ "Web", "debian" ] ], granted
  end

  test "converting a key without profile into a profile from the server page" do
    bob = SshKeyGenerator.generate(comment: "bob@desktop").public_key
    reader = ->(*, **) { AuthorizedKeysReader::Result.new(keys: AuthorizedKey.parse([ ssh_keys(:main).public_key, bob ].join("\n")), error_title: nil, error_details: nil) }
    accounts = ->(server, **) { ServerAccountsReader::Result.new(accounts: [ AuthorizedKeysAccount.login(server) ], error_title: nil, error_details: nil) }

    stub_method(AuthorizedKeysReader, :call, reader) do
      stub_method(ServerAccountsReader, :call, accounts) do
        visit server_path(servers(:web))

        within("#server-authorized-keys") do
          assert_selector ".orphan-warning", text: "1 clé ne correspond à aucun profil"
          within("li.is-orphan", text: "bob@desktop") { click_on "Créer un profil" }
        end

        assert_selector "h1", text: "Ajouter un profil"
        assert_field "Nom", with: "bob"
        assert_field "Clé SSH publique", with: bob
        fill_in "Nom", with: "Bob"
        click_on "Ajouter le profil"

        assert_selector "#flash", text: "Le profil « Bob » a été ajouté."
        assert_selector "h1", text: "Web"
        within("#server-authorized-keys") do
          assert_selector ".key-profile", text: "Profil : Bob"
          assert_no_selector ".orphan-warning"
          assert_no_selector "li.is-orphan"
        end
      end
    end
  end
end
