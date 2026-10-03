require "test_helper"

class RevokeProfileEverywhereJobTest < ActiveJob::TestCase
  include StubHelpers

  setup do
    @revocation = Revocation.start!(profiles(:alice), by: users(:one))
    @calls = []
    # Web: deploy + root; Database: admin; Backup: accounts cannot be listed.
    @accounts = lambda do |server, **|
      next ServerAccountsReader::Result.new(accounts: [], error_title: "Connexion impossible", error_details: "refused") if server.name == "Backup"

      names = server.name == "Web" ? %w[deploy root] : %w[admin]
      ServerAccountsReader::Result.new(accounts: names.map { |name| AuthorizedKeysAccount.for(server, name) }, error_title: nil, error_details: nil)
    end
  end

  def removal(status)
    lambda do |server, blob, account:, **|
      @calls << [ server.name, account.unix_user, blob ]
      AuthorizedKeyRemoval::Result.new(status: status.respond_to?(:call) ? status.call(server, account) : status,
                                       error_title: "Clé SSH refusée par le serveur", error_details: "x")
    end
  end

  def run_job(status, **options)
    stub_method(ServerAccountsReader, :call, @accounts) do
      stub_method(AuthorizedKeyRemoval, :call, removal(status)) { RevokeProfileEverywhereJob.perform_now(@revocation, **options) }
    end
  end

  test "removes the key from every discovered account and records each step" do
    run_job(->(server, account) { account.unix_user == "root" ? :absent : :removed })

    blob = profiles(:alice).authorized_key.key
    assert_equal [ [ "Database", "admin", blob ], [ "Web", "deploy", blob ], [ "Web", "root", blob ] ], @calls.sort
    steps = @revocation.steps.reload.map { |step| [ step.server_name, step.unix_user, step.status ] }
    assert_equal [ [ "Backup", nil, "failed" ], [ "Database", "admin", "removed" ], [ "Web", "deploy", "removed" ], [ "Web", "root", "absent" ] ], steps
    assert_match "Connexion impossible", @revocation.steps.find_by(server_name: "Backup").error_message
    assert_not @revocation.reload.running?
    assert_equal :partial, @revocation.status
  end

  test "removals are logged as the admin who started the revocation" do
    run_job(:removed)

    activity = Activity.of_kind(:key_removed).first
    assert_equal users(:one), activity.user
    assert_nil Current.user
  end

  test "retrying redoes only the failed accounts and the servers that could not be listed" do
    run_job(->(server, account) { account.unix_user == "admin" ? :error : :removed })
    assert_equal 2, @revocation.reload.failed_count
    @calls.clear
    @accounts = ->(server, **) { ServerAccountsReader::Result.new(accounts: [ AuthorizedKeysAccount.login(server) ], error_title: nil, error_details: nil) }

    run_job(:removed, retry_failed: true)

    assert_equal [ [ "Backup", "root" ], [ "Database", "admin" ] ], @calls.map { |server, user, _| [ server, user ] }.sort
    assert_equal 0, @revocation.reload.failed_count
    assert_equal :succeeded, @revocation.status
    assert_equal 2, Activity.of_kind(:profile_revoked_everywhere).count
  end
end
