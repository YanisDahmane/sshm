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

  test "shows the setup checklist until every step is done" do
    sign_in users(:one)
    get root_path

    assert_select "#onboarding" do
      assert_select ".onboarding-step", 5
      assert_select "#onboarding-ssh_key.is-done"
      assert_select "#onboarding-server.is-done"
      assert_select "#onboarding-install_key:not(.is-done)" do
        assert_select ".ssh-setup-hint textarea", text: /authorized_keys/
        assert_select "a[href=?]", server_path(servers(:backup)), text: /Ouvrir Backup pour tester/
      end
    end
  end

  test "the checklist starts with generating the SSHM key" do
    SshKey.delete_all
    sign_in users(:one)
    get root_path

    assert_select "#onboarding-ssh_key:not(.is-done) form[action=?] button", ssh_key_path, text: "Générer la clé"
  end

  test "hides the checklist once everything is done" do
    servers(:web).record_ssh_status!(true)
    AccountSnapshot.record!(servers(:web), AuthorizedKeysAccount.login(servers(:web)), AuthorizedKey.parse(profiles(:alice).public_key))
    sign_in users(:one)

    get root_path

    assert_select "#onboarding", 0
  end

  test "shows the key figures" do
    unnamed = SshKeyGenerator.generate.public_key.split(" ").first(2).join(" ")
    AccountSnapshot.record!(servers(:web), AuthorizedKeysAccount.login(servers(:web)), AuthorizedKey.parse(unnamed))
    TemporaryAccess.create!(server: servers(:web), profile: profiles(:ci), unix_user: "deploy", key_blob: profiles(:ci).authorized_key.key,
                            fingerprint: profiles(:ci).fingerprint, expires_at: 9.minutes.from_now)
    sign_in users(:one)

    get root_path

    assert_select "a#stat-online[href=?] .stat-value", servers_path, "1/3"
    assert_select "a#stat-orphans[href='#attention'] .stat-value", "1"
    assert_select "#stat-temporary .stat-value", "1"
    assert_select "a#stat-profiles[href=?] .stat-value", profiles_path, "2"
  end

  test "the keys without profile figure asks for a scan before any read" do
    sign_in users(:one)
    get root_path

    assert_select "#stat-orphans .stat-value", "—"
    assert_select "#stat-orphans", text: /Lancez un scan/
    assert_select "form[action=?]", server_scans_path
  end

  test "lists the temporary accesses in progress" do
    access = TemporaryAccess.create!(server: servers(:web), profile: profiles(:ci), unix_user: "deploy", key_blob: profiles(:ci).authorized_key.key,
                                     fingerprint: profiles(:ci).fingerprint, expires_at: 9.minutes.from_now + 30.seconds)
    sign_in users(:one)

    get root_path

    assert_select "#temporary-accesses ##{ActionView::RecordIdentifier.dom_id(access)}" do
      assert_select "p", text: "CI"
      assert_select "a[href=?]", server_path(servers(:web)), text: "Web"
      assert_select "time[data-controller=relative-time]", text: "Expire dans 10 minutes"
    end
  end

  test "lists the servers that need attention" do
    servers(:backup).record_ssh_status!(false)
    sign_in users(:one)

    get root_path

    assert_select "#attention li", 2
    assert_select "#attention li", text: /Database/ # unreachable
    assert_select "#attention li", text: /Backup/ do # key refused
      assert_select ".ssh-status", text: /Clé refusée/
    end
  end

  test "has the main navigation with the current page highlighted" do
    sign_in users(:one)

    get root_path
    assert_select "nav .main-nav a[aria-current=page]", text: "Dashboard"
    assert_select "nav .main-nav a[href=?]", servers_path, text: "Serveurs"
    assert_select "nav .main-nav a[href=?]", profiles_path, text: "Profils"

    get server_path(servers(:web))
    assert_select "nav .main-nav a[aria-current=page]", text: "Serveurs"

    get profiles_path
    assert_select "nav .main-nav a[aria-current=page]", text: "Profils"
  end

  test "includes the quick search, its button and the confirm dialog when signed in" do
    sign_in users(:one)
    get root_path

    assert_select "body[data-controller=command-palette]"
    assert_select "dialog#command-palette script[type='application/json']", text: /"label":"Web"/
    assert_select "button.command-palette-button[data-action='command-palette#open']"
    assert_select "dialog#confirm-dialog button[data-confirm-accept]"
    assert_select "#flash[aria-live=polite]"
  end

  test "no quick search on the sign in page" do
    get new_user_session_path

    assert_select "dialog#command-palette", 0
    assert_select "#flash"
  end

  test "flash messages are rendered as toasts" do
    sign_in users(:one)
    post server_scans_path
    follow_redirect!

    assert_select "#flash .toast.toast-notice[data-controller=toast][role=status]", text: /Scan des clés lancé/ do
      assert_select "button[data-action='toast#dismiss'][aria-label=Fermer]"
    end
  end

  test "warns about keys without profile in the attention list, with their names" do
    keys = [ "alice2@laptop", "bob@desktop", nil, "dave@ci" ].map { |comment| SshKeyGenerator.generate(comment: comment.to_s).public_key.strip }
    AccountSnapshot.record!(servers(:web), AuthorizedKeysAccount.login(servers(:web)), AuthorizedKey.parse(keys.join("\n")))
    sign_in users(:one)

    get root_path

    assert_select "#attention-#{ActionView::RecordIdentifier.dom_id(servers(:web))}" do
      assert_select ".orphan-keys", text: "4 clés sans profil"
      assert_select ".attention-orphans", text: /alice2@laptop, bob@desktop, sans nom et 1 autre\(s\)/
      assert_select ".attention-orphans a[href=?]", server_path(servers(:web), anchor: "server-authorized-keys"), text: "convertir en profil"
    end
  end

  test "a named key without profile is to watch too" do
    AccountSnapshot.record!(servers(:web), AuthorizedKeysAccount.login(servers(:web)), AuthorizedKey.parse(SshKeyGenerator.generate(comment: "bob@desktop").public_key))
    sign_in users(:one)

    get root_path

    assert_select "#attention-#{ActionView::RecordIdentifier.dom_id(servers(:web))} .attention-orphans", text: /bob@desktop/
  end

  test "shows the recent activity" do
    9.times { |index| travel_to(index.minutes.ago) { Activity.record!(:server_created, server: servers(:web)) } }
    sign_in users(:one)

    get root_path

    assert_select "#recent-activity li.activity", 8
    assert_select "#recent-activity a[href=?]", activities_path, text: "Tout voir"
    assert_select "nav .main-nav a[href=?]", activities_path, text: "Activité"
  end
end
