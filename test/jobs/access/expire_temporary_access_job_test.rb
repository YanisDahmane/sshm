require "test_helper"

class ExpireTemporaryAccessJobTest < ActiveJob::TestCase
  include StubHelpers
  include TemporaryAccessHelpers

  def removal(status)
    ->(*, **) { Keys::AuthorizedKeyRemoval::Result.new(status: status, error_title: (status == :error ? "Connexion impossible" : nil), error_details: nil) }
  end

  test "removes the key from the account and ends the access" do
    access = create_temporary_access(expires_at: 1.minute.ago)
    calls = []
    remover = lambda do |server, blob, account:, **|
      calls << [ server, blob, account ]
      Keys::AuthorizedKeyRemoval::Result.new(status: :removed, error_title: nil, error_details: nil)
    end

    stub_method(Keys::AuthorizedKeyRemoval, :call, remover) { ExpireTemporaryAccessJob.perform_now(access) }

    assert_equal [ [ servers(:web), public_keys(:ci).authorized_key.key, AuthorizedKeysAccount.login(servers(:web)) ] ], calls
    assert_not access.reload.active?
  end

  test "ends the access when the key is already gone" do
    access = create_temporary_access(expires_at: 1.minute.ago)

    stub_method(Keys::AuthorizedKeyRemoval, :call, removal(:absent)) { ExpireTemporaryAccessJob.perform_now(access) }

    assert_not access.reload.active?
  end

  test "does nothing for an access that already ended" do
    access = create_temporary_access(expires_at: 1.minute.ago).tap(&:end!)

    stub_method(Keys::AuthorizedKeyRemoval, :call, ->(*, **) { flunk "should not remove" }) { ExpireTemporaryAccessJob.perform_now(access) }
    assert_not access.reload.active?
  end

  test "reschedules itself when run too early" do
    access = create_temporary_access(expires_at: 5.minutes.from_now)

    stub_method(Keys::AuthorizedKeyRemoval, :call, ->(*, **) { flunk "should not remove" }) { ExpireTemporaryAccessJob.perform_now(access) }

    assert access.reload.active?
    assert_enqueued_with(job: ExpireTemporaryAccessJob, args: [ access ], at: access.expires_at)
  end

  test "retries later when the server cannot be reached" do
    access = create_temporary_access(expires_at: 1.minute.ago)

    stub_method(Keys::AuthorizedKeyRemoval, :call, removal(:error)) { ExpireTemporaryAccessJob.perform_now(access) }

    assert access.reload.active?
    assert_enqueued_jobs 1, only: ExpireTemporaryAccessJob
  end

  test "is discarded when the access was deleted" do
    access = create_temporary_access(expires_at: 1.minute.ago)
    serialized = ExpireTemporaryAccessJob.new(access).serialize
    access.delete

    assert_nothing_raised { ActiveJob::Base.execute(serialized) }
  end

  test "removes the expired key from the account snapshot" do
    access = create_temporary_access(expires_at: 1.minute.ago)
    AccountSnapshot.record!(servers(:web), access.account, AuthorizedKey.parse([ public_keys(:ci).content, public_keys(:alice).content ].join("\n")))

    stub_method(Keys::AuthorizedKeyRemoval, :call, removal(:removed)) { ExpireTemporaryAccessJob.perform_now(access) }

    assert_equal [ public_keys(:alice).fingerprint ], AccountSnapshot.sole.fingerprints
  end

  test "logs the expiry as a system activity" do
    access = create_temporary_access(expires_at: 1.minute.ago)

    stub_method(Keys::AuthorizedKeyRemoval, :call, removal(:removed)) { ExpireTemporaryAccessJob.perform_now(access) }

    activity = Activity.of_kind(:key_expired).sole
    assert_equal [ servers(:web), public_keys(:ci), "deploy", "Système" ], [ activity.server, activity.public_key, activity.unix_user, activity.author_name ]
  end
end
