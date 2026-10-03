require "test_helper"

class AccessGrantTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper
  include StubHelpers
  include TemporaryAccessHelpers

  setup do
    @server = servers(:web)
    @account = AuthorizedKeysAccount.login(@server)
    @calls = []
  end

  # Stubs ProfileAuthorization.call, records its keyword arguments and returns `status`.
  def with_authorization(status)
    authorizer = lambda do |_server, _profile, **options|
      @calls << options
      ProfileAuthorization::Result.new(status: status, error_title: (status == :error ? "Connexion impossible" : nil), error_details: nil)
    end
    stub_method(ProfileAuthorization, :call, authorizer) { yield }
  end

  test "a permanent grant records nothing" do
    with_authorization(:added) { AccessGrant.call(@server, profiles(:alice), account: @account) }

    assert_equal [ { account: @account, expires_at: nil, replace: false } ], @calls
    assert_equal 0, TemporaryAccess.count
    assert_no_enqueued_jobs
  end

  test "a temporary grant writes an expiring line, records the access and schedules its expiry" do
    freeze_time do
      with_authorization(:added) { AccessGrant.call(@server, profiles(:alice), account: @account, duration: 10.minutes) }

      assert_equal 10.minutes.from_now, @calls.sole[:expires_at]
      access = TemporaryAccess.sole
      assert_equal [ @server, profiles(:alice), "deploy", profiles(:alice).authorized_key.key, profiles(:alice).fingerprint, 10.minutes.from_now ],
                   [ access.server, access.profile, access.unix_user, access.key_blob, access.fingerprint, access.expires_at ]
      assert_enqueued_with(job: ExpireTemporaryAccessJob, args: [ access ], at: 10.minutes.from_now)
    end
  end

  test "a temporary grant on a key already authorized permanently keeps it permanent" do
    with_authorization(:already_present) { AccessGrant.call(@server, profiles(:alice), account: @account, duration: 10.minutes) }

    assert_equal 0, TemporaryAccess.count
    assert_no_enqueued_jobs
  end

  test "a permanent grant replaces the line of an active temporary access and ends it" do
    access = create_temporary_access

    with_authorization(:added) { AccessGrant.call(@server, profiles(:ci), account: @account) }

    assert @calls.sole[:replace]
    assert_nil @calls.sole[:expires_at]
    assert_not access.reload.active?
    assert_equal 0, TemporaryAccess.active.count
  end

  test "a new temporary grant replaces an active one" do
    old = create_temporary_access

    with_authorization(:added) { AccessGrant.call(@server, profiles(:ci), account: @account, duration: 1.hour) }

    assert @calls.sole[:replace]
    assert_not old.reload.active?
    assert_in_delta 1.hour.from_now, TemporaryAccess.active.sole.expires_at, 5
  end

  test "temporary accesses are per account" do
    root_access = create_temporary_access(unix_user: "root")

    with_authorization(:added) { AccessGrant.call(@server, profiles(:ci), account: @account) }

    assert_not @calls.sole[:replace]
    assert root_access.reload.active?
  end

  test "changes nothing when the authorization fails" do
    access = create_temporary_access

    result = with_authorization(:error) { AccessGrant.call(@server, profiles(:ci), account: @account, duration: 10.minutes) }

    assert_not result.success?
    assert access.reload.active?
    assert_equal 1, TemporaryAccess.count
    assert_no_enqueued_jobs
  end
end
