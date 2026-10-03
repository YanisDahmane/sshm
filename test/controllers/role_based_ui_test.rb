require "test_helper"

# Controls the role cannot use are not shown.
class RoleBasedUiTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers
  include StubHelpers

  setup do
    keys = AuthorizedKeysReader::Result.new(keys: AuthorizedKey.parse([ ssh_keys(:main).public_key, SshKeyGenerator.generate(comment: "bob").public_key ].join("\n")), error_title: nil, error_details: nil)
    stub_method_until_teardown(AuthorizedKeysReader, :call, keys)
    stub_method_until_teardown(ServerAccountsReader, :call, ->(server, **) { ServerAccountsReader::Result.new(accounts: [ AuthorizedKeysAccount.login(server) ], error_title: nil, error_details: nil) })
  end

  test "the navbar shows the role, and the settings to admins only" do
    { one: [ "Admin", 1 ], operator: [ "Opérateur", 0 ], viewer: [ "Lecture", 0 ] }.each do |role, (label, settings_links)|
      sign_in users(role)
      get root_path
      assert_select "nav .user-role", label
      assert_select "nav a[title=Paramètres]", settings_links
    end
  end

  test "a viewer sees no management controls" do
    sign_in users(:viewer)

    get root_path
    assert_select "#onboarding", 0
    assert_select "form[action=?]", server_scans_path, 0

    get servers_path
    assert_select "a[href=?]", new_server_path, 0
    assert_select "a[title=Modifier]", 0
    assert_select "form[action=?]", server_scans_path, 0
    assert_select "button[title='Actualiser le statut']" # read-only checks stay available

    get server_path(servers(:web))
    assert_select "a[href=?]", edit_server_path(servers(:web)), 0
    assert_select "button.delete-server", 0

    get server_authorized_keys_path(servers(:web))
    assert_select "form.authorize-profile", 0
    assert_select "button[title='Supprimer la clé']", 0
    assert_select "a.create-profile", 0
    assert_select "button.key-details-button", 2

    get profiles_path
    assert_select "a[href=?]", new_profile_path, 0
    assert_select "button[title=Supprimer]", 0

    get profile_path(profiles(:alice))
    assert_select "a[href=?]", edit_profile_path(profiles(:alice)), 0
    assert_select "#bulk-authorize", 0
  end

  test "an operator manages servers, keys and profiles but not the settings" do
    sign_in users(:operator)

    get root_path
    assert_select "#onboarding", 0
    assert_select "form[action=?]", server_scans_path

    get servers_path
    assert_select "a[href=?]", new_server_path

    get server_authorized_keys_path(servers(:web))
    assert_select "form.authorize-profile"
    assert_select "button[title='Supprimer la clé']", 1
    assert_select "a.create-profile", 1

    get profile_path(profiles(:alice))
    assert_select "#bulk-authorize"
  end

  test "the setup hint asks a non-admin to contact an administrator" do
    SshKey.delete_all
    stub_method_until_teardown(SshCheck, :call, SshCheck::Result.new(success: false, message: "Aucune clé SSH configurée", details: "x", reason: :missing_key))
    sign_in users(:operator)

    get server_ssh_check_path(servers(:web))

    assert_select ".ssh-setup-hint a[href=?]", settings_path, 0
    assert_select ".ssh-setup-hint", text: /Demandez à un administrateur/
  end
end
