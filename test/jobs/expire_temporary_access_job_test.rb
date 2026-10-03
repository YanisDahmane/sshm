require "test_helper"

class ExpireTemporaryAccessJobTest < ActiveJob::TestCase
  include StubHelpers
  include TemporaryAccessHelpers

  def removal(status)
    ->(*, **) { AuthorizedKeyRemoval::Result.new(status: status, error_title: (status == :error ? "Connexion impossible" : nil), error_details: nil) }
  end

  test "removes the key from the account and ends the access" do
    access = create_temporary_access(unix_user: "root", expires_at: 1.minute.ago)
    calls = []
    remover = lambda do |server, blob, account:, **|
      calls << [ server, blob, account ]
      AuthorizedKeyRemoval::Result.new(status: :removed, error_title: nil, error_details: nil)
    end

    stub_method(AuthorizedKeyRemoval, :call, remover) { ExpireTemporaryAccessJob.perform_now(access) }

    assert_equal [ [ servers(:web), profiles(:ci).authorized_key.key, AuthorizedKeysAccount.for(servers(:web), "root") ] ], calls
    assert_not access.reload.active?
  end

  test "ends the access when the key is already gone" do
    access = create_temporary_access(expires_at: 1.minute.ago)

    stub_method(AuthorizedKeyRemoval, :call, removal(:absent)) { ExpireTemporaryAccessJob.perform_now(access) }

    assert_not access.reload.active?
  end

  test "does nothing for an access that already ended" do
    access = create_temporary_access(expires_at: 1.minute.ago).tap(&:end!)

    stub_method(AuthorizedKeyRemoval, :call, ->(*, **) { flunk "should not remove" }) { ExpireTemporaryAccessJob.perform_now(access) }
  end

  test "reschedules itself when run too early" do
    access = create_temporary_access(expires_at: 5.minutes.from_now)

    stub_method(AuthorizedKeyRemoval, :call, ->(*, **) { flunk "should not remove" }) { ExpireTemporaryAccessJob.perform_now(access) }

    assert access.reload.active?
    assert_enqueued_with(job: ExpireTemporaryAccessJob, args: [ access ], at: access.expires_at)
  end

  test "retries later when the server cannot be reached" do
    access = create_temporary_access(expires_at: 1.minute.ago)

    stub_method(AuthorizedKeyRemoval, :call, removal(:error)) { ExpireTemporaryAccessJob.perform_now(access) }

    assert access.reload.active?
    assert_enqueued_jobs 1, only: ExpireTemporaryAccessJob
  end

  test "is discarded when the access was deleted" do
    access = create_temporary_access(expires_at: 1.minute.ago)
    serialized = ExpireTemporaryAccessJob.new(access).serialize
    access.delete

    assert_nothing_raised { ActiveJob::Base.execute(serialized) }
  end
end
