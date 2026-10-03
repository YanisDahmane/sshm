require "test_helper"

# Every action, for every role: allowed (any status but 403) or forbidden (403).
class AuthorizationTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers
  include StubHelpers
  include SlackHelpers

  ROLES = %i[one operator viewer].freeze # admin, operator, viewer
  ALLOWED = { view: %i[one operator viewer], operate: %i[one operator], administer: %i[one] }.freeze

  setup do
    # Nothing may reach a real server or Slack.
    ok_keys = AuthorizedKeysReader::Result.new(keys: [], error_title: nil, error_details: nil)
    stub_method_until_teardown(AuthorizedKeysReader, :call, ok_keys)
    stub_method_until_teardown(ServerAccountsReader, :call, ->(server, **) { ServerAccountsReader::Result.new(accounts: [ AuthorizedKeysAccount.login(server) ], error_title: nil, error_details: nil) })
    stub_method_until_teardown(SshCheck, :call, SshCheck::Result.new(success: true, message: "ok", details: "ok"))
    stub_method_until_teardown(ServerPing, :reachable?, true)
    stub_method_until_teardown(AccessGrant, :call, ProfileAuthorization::Result.new(status: :added, error_title: nil, error_details: nil))
    stub_method_until_teardown(KeyRevocation, :call, AuthorizedKeyRemoval::Result.new(status: :removed, error_title: nil, error_details: nil))
    stub_method_until_teardown(SlackNotifier, :post, nil)
  end


  REQUESTS = {
    view: {
      "dashboard" => -> { get root_path },
      "servers index" => -> { get servers_path },
      "server page" => -> { get server_path(servers(:web)) },
      "server port check" => -> { get server_ping_path(servers(:web)) },
      "server SSH check" => -> { get server_ssh_check_path(servers(:web)) },
      "server keys" => -> { get server_authorized_keys_path(servers(:web)) },
      "ping one server" => -> { post server_ping_path(servers(:web)) },
      "ping all servers" => -> { post server_pings_path },
      "profiles index" => -> { get profiles_path },
      "profile page" => -> { get profile_path(profiles(:alice)) },
      "activities" => -> { get activities_path },
      "own account" => -> { get account_path },
      "set up 2FA" => -> { get new_two_factor_path }
    },
    operate: {
      "new server" => -> { get new_server_path },
      "create server" => -> { post servers_path, params: { server: { name: "New", host: "10.0.0.1", port: 22, username: "root" } } },
      "edit server" => -> { get edit_server_path(servers(:web)) },
      "update server" => -> { patch server_path(servers(:web)), params: { server: { name: "Renamed" } } },
      "delete server" => -> { delete server_path(servers(:web)) },
      "scan keys" => -> { post server_scans_path },
      "authorize a profile" => -> { post server_authorizations_path(servers(:web)), params: { profile_id: profiles(:alice).id } },
      "remove a key" => -> { delete server_authorized_key_path(servers(:web)), params: { key: "AAAA" } },
      "new profile" => -> { get new_profile_path },
      "create profile" => -> { post profiles_path, params: { profile: { name: "New", public_key: SshKeyGenerator.generate.public_key } } },
      "edit profile" => -> { get edit_profile_path(profiles(:alice)) },
      "update profile" => -> { patch profile_path(profiles(:alice)), params: { profile: { name: "Renamed" } } },
      "delete profile" => -> { delete profile_path(profiles(:alice)) },
      "grant a profile on servers" => -> { post profile_accesses_path(profiles(:alice)), params: { server_ids: [ servers(:web).id ] } },
      "revoke a profile access" => -> { delete profile_access_path(profiles(:alice)), params: { server_id: servers(:web).id, account: "deploy" } }
    },
    administer: {
      "general settings" => -> { get settings_path },
      "generate the SSHM key" => -> { post ssh_key_path },
      "trust a new host key" => -> { post server_host_key_path(servers(:web)), params: { fingerprint: "SHA256:new" } },
      "notifications" => -> { get settings_notifications_path },
      "new channel" => -> { get new_settings_notification_channel_path },
      "create channel" => -> { post settings_notification_channels_path, params: { notification_channel: { name: "#x", webhook_url: WEBHOOK, activity_kinds: [ "" ] } } },
      "edit channel" => -> { get edit_settings_notification_channel_path(create_channel) },
      "test channel" => -> { post test_settings_notification_channel_path(create_channel) },
      "delete channel" => -> { delete settings_notification_channel_path(create_channel) },
      "automations" => -> { get settings_automations_path },
      "update automation" => -> { patch settings_automation_path(Automation.all_kinds.first), params: { automation: { enabled: "1", interval_minutes: "60" } } },
      "run automation" => -> { post run_settings_automation_path(Automation.all_kinds.first) },
      "users" => -> { get settings_users_path },
      "invite a user" => -> { post settings_invitations_path, params: { invitation: { email: "new@example.com", role: "viewer" } } },
      "revoke an invitation" => -> { delete settings_invitation_path(Invitation.create!(email: "x@example.com", invited_by: users(:one))) },
      "change a user's role" => -> { patch settings_user_path(users(:viewer)), params: { user: { role: "operator", profile_id: "" } } },
      "deactivate a user" => -> { post deactivate_settings_user_path(users(:viewer)) },
      "reactivate a user" => -> { post reactivate_settings_user_path(users(:viewer)) },
      "reset a user's 2FA" => -> { post reset_two_factor_settings_user_path(users(:viewer)) },
      "revoke a profile everywhere" => -> { post profile_revocation_path(profiles(:alice)) },
      "follow a revocation" => -> { get revocation_path(Revocation.start!(profiles(:alice), by: users(:one))) },
      "retry a revocation" => -> { post retry_revocation_path(Revocation.start!(profiles(:alice), by: users(:one)).tap(&:finish!)) },
      "start a key rotation" => -> { post settings_key_rotations_path },
      "follow a key rotation" => -> { get settings_key_rotation_path(KeyRotation.start!(by: users(:one))) },
      "retry a key rotation" => -> { post retry_settings_key_rotation_path(KeyRotation.start!(by: users(:one))) },
      "finalize a key rotation" => -> { post finalize_settings_key_rotation_path(KeyRotation.start!(by: users(:one))) },
      "require 2FA for admins" => -> { patch settings_security_path, params: { app_setting: { require_admin_two_factor: "0" } } }
    }
  }.freeze

  REQUESTS.each do |permission, requests|
    requests.each do |name, request|
      ROLES.each do |role|
        allowed = ALLOWED.fetch(permission).include?(role)

        test "#{role == :one ? "admin" : role} #{allowed ? "can" : "cannot"} #{name}" do
          sign_in users(role)
          instance_exec(&request)

          if allowed
            assert_not_equal 403, response.status, "#{name} should be allowed for #{role}"
            assert_operator response.status, :<, 500
          else
            assert_response :forbidden
          end
        end
      end
    end
  end

  test "signed out users are still sent to the sign in page" do
    get servers_path
    assert_redirected_to new_user_session_path
  end

  test "a forbidden page explains why" do
    sign_in users(:viewer)
    get new_server_path

    assert_select "h1", "Accès refusé"
    assert_select "p", text: "Votre rôle (Lecture) ne permet pas cette action."
  end

  test "a forbidden Turbo Stream request shows a toast" do
    sign_in users(:viewer)
    post server_authorizations_path(servers(:web)), params: { profile_id: profiles(:alice).id }, as: :turbo_stream

    assert_turbo_stream action: :update, target: "flash", status: :forbidden do
      assert_select ".toast-alert", text: /Votre rôle \(Lecture\) ne permet pas cette action/
    end
  end

  test "a forbidden Turbo Frame request answers inside the frame" do
    sign_in users(:viewer)
    get new_server_path, headers: { "Turbo-Frame" => "some_frame" }

    assert_response :forbidden
    assert_select "turbo-frame#some_frame p.forbidden"
  end

  test "nothing changes when an action is forbidden" do
    sign_in users(:viewer)

    assert_no_difference -> { Server.count } do
      delete server_path(servers(:web))
    end
    assert_no_difference -> { SshKey.count + Activity.count } do
      post ssh_key_path
    end
  end
end
