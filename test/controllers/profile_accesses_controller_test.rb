require "test_helper"

class ProfileAccessesControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers
  include StubHelpers
  include TemporaryAccessHelpers

  setup do
    @profile = profiles(:alice)
    @grants = []
    # After a grant, the controller re-reads the account to refresh its snapshot.
    stub_method_until_teardown(AuthorizedKeysReader, :call, ->(*, **) { AuthorizedKeysReader::Result.new(keys: AuthorizedKey.parse(@profile.public_key), error_title: nil, error_details: nil) })
  end

  def granter(status_for = ->(_server) { :added })
    lambda do |server, profile, account:, duration:, **|
      @grants << [ server.name, profile.name, account.unix_user, duration ]
      status = status_for.call(server)
      ProfileAuthorization::Result.new(status: status, error_title: (status == :error ? "Connexion impossible" : nil), error_details: (status == :error ? "refused" : nil))
    end
  end

  test "requires authentication" do
    post profile_accesses_path(@profile), params: { server_ids: [ servers(:web).id ] }
    assert_redirected_to new_user_session_path

    delete profile_access_path(@profile), params: { server_id: servers(:web).id, account: "deploy" }
    assert_redirected_to new_user_session_path
  end

  test "grants the profile on each selected server's login user" do
    sign_in users(:one)

    stub_method(AccessGrant, :call, granter) do
      post profile_accesses_path(@profile), params: { server_ids: [ servers(:web).id, servers(:db).id ] }, as: :turbo_stream
    end

    assert_equal [ [ "Database", "Alice", "admin", nil ], [ "Web", "Alice", "deploy", nil ] ], @grants
    assert_turbo_stream action: :update, target: "bulk-results" do
      assert_select "li.bulk-result.is-success", 2
      assert_select "li.bulk-result", text: "Web · deploy : autorisé"
    end
    assert_turbo_stream action: :replace, target: "profile-accesses" do
      assert_select "li.profile-access", 2
    end
    assert_turbo_stream action: :update, target: "flash" do
      assert_select ".toast-notice", text: /Autorisations terminées : 2\/2 serveur\(s\)\./
    end
    assert_equal 2, AccountSnapshot.count
  end

  test "grants the same named account everywhere, for a limited time" do
    sign_in users(:one)

    stub_method(AccessGrant, :call, granter) do
      post profile_accesses_path(@profile), params: { server_ids: [ servers(:web).id ], account: " debian ", duration: "60" }, as: :turbo_stream
    end

    assert_equal [ [ "Web", "Alice", "debian", 1.hour ] ], @grants
    assert_turbo_stream action: :update, target: "bulk-results" do
      assert_select "li.bulk-result", text: "Web · debian : autorisé pendant 1 heure"
    end
  end

  test "reports each server's outcome" do
    sign_in users(:one)
    statuses = { "Web" => :already_present, "Database" => :error }

    stub_method(AccessGrant, :call, granter(->(server) { statuses.fetch(server.name) })) do
      post profile_accesses_path(@profile), params: { server_ids: [ servers(:web).id, servers(:db).id ] }, as: :turbo_stream
    end

    assert_turbo_stream action: :update, target: "bulk-results" do
      assert_select "li.bulk-result.is-success", text: "Web · deploy : déjà autorisé"
      assert_select "li.bulk-result.is-error", text: "Database · admin : Connexion impossible — refused"
    end
    assert_turbo_stream action: :update, target: "flash" do
      assert_select ".toast-notice", text: /1\/2/
    end
    assert_equal 1, AccountSnapshot.count
  end

  test "an invalid account name is reported, not granted" do
    sign_in users(:one)

    stub_method(AccessGrant, :call, granter) do
      post profile_accesses_path(@profile), params: { server_ids: [ servers(:web).id ], account: "bad name" }, as: :turbo_stream
    end

    assert_empty @grants
    assert_turbo_stream action: :update, target: "bulk-results" do
      assert_select "li.bulk-result.is-error", text: /Nom de compte invalide/
    end
  end

  test "asks to choose a server" do
    sign_in users(:one)

    post profile_accesses_path(@profile), params: {}

    assert_redirected_to profile_path(@profile)
    assert_equal "Choisissez au moins un serveur.", flash[:alert]
  end

  test "rejects a duration that is not offered" do
    sign_in users(:one)
    post profile_accesses_path(@profile), params: { server_ids: [ servers(:web).id ], duration: "3" }
    assert_response :bad_request
  end

  test "revokes one access and updates the snapshot and temporary access" do
    sign_in users(:one)
    profile = profiles(:ci)
    AccountSnapshot.record!(servers(:web), AuthorizedKeysAccount.login(servers(:web)), AuthorizedKey.parse(profile.public_key))
    access = create_temporary_access(profile: profile)
    calls = []
    remover = lambda do |server, blob, account:, **|
      calls << [ server, blob, account.unix_user ]
      AuthorizedKeyRemoval::Result.new(status: :removed, error_title: nil, error_details: nil)
    end

    stub_method(AuthorizedKeyRemoval, :call, remover) do
      delete profile_access_path(profile), params: { server_id: servers(:web).id, account: "deploy" }, as: :turbo_stream
    end

    assert_equal [ [ servers(:web), profile.authorized_key.key, "deploy" ] ], calls
    assert_not access.reload.active?
    assert_empty AccountSnapshot.sole.fingerprints
    assert_turbo_stream action: :replace, target: "profile-accesses" do
      assert_select "li.profile-access", 0
    end
    assert_turbo_stream action: :update, target: "flash" do
      assert_select ".toast-notice", text: "L'accès de « CI » à « Web » pour deploy a été retiré."
    end
  end

  test "keeps everything when the revocation fails" do
    sign_in users(:one)
    AccountSnapshot.record!(servers(:web), AuthorizedKeysAccount.login(servers(:web)), AuthorizedKey.parse(@profile.public_key))
    failed = AuthorizedKeyRemoval::Result.new(status: :error, error_title: "Connexion impossible", error_details: "refused")

    stub_method(AuthorizedKeyRemoval, :call, failed) do
      delete profile_access_path(@profile), params: { server_id: servers(:web).id, account: "deploy" }, as: :turbo_stream
    end

    assert_equal [ @profile.fingerprint ], AccountSnapshot.sole.fingerprints
    assert_turbo_stream action: :update, target: "flash" do
      assert_select ".toast-alert", text: /Impossible de retirer l'accès : Connexion impossible/
    end
  end

  test "revoking rejects an invalid account name" do
    sign_in users(:one)
    delete profile_access_path(@profile), params: { server_id: servers(:web).id, account: "../root" }
    assert_response :bad_request
  end

  test "the profile page shows its accesses and the bulk form" do
    AccountSnapshot.record!(servers(:web), AuthorizedKeysAccount.login(servers(:web)), AuthorizedKey.parse(@profile.public_key))
    sign_in users(:one)

    get profile_path(@profile)

    assert_select "#profile-accesses li.profile-access", 1 do
      assert_select "a[href=?]", server_path(servers(:web)), text: "Web"
      assert_select "span", text: "Permanent"
      assert_select "form[action=?][data-turbo-confirm][data-confirm-variant=danger]", profile_access_path(@profile)
    end
    assert_select "#bulk-authorize form[action=?]", profile_accesses_path(@profile) do
      assert_select "input[type=checkbox][name='server_ids[]']", 3
      assert_select "input[name=account][placeholder=?]", "ex. debian"
      assert_select "select[name=duration] option[value='60']", "1 heure"
    end
  end
end
