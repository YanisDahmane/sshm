require "test_helper"

class RotateSshKeyJobTest < ActiveJob::TestCase
  include StubHelpers

  # Pretends to talk to the servers; `failures` maps a server name to the phase that fails there.
  class FakeServers
    attr_reader :installs, :checks, :removals

    def initialize(failures = {})
      @failures = failures
      @installs = []
      @checks = []
      @removals = []
    end

    def open(server, key:, **)
      raise SshConnection::ConnectionError, "refused" if @failures[server.name] == "install"

      @installs << [ server.name, key.map(&:state) ]
      yield Object.new.tap { |ssh| def ssh.exec!(*) = true }
    end

    def check(server, key:, **)
      @checks << [ server.name, key.state ]
      ok = @failures[server.name] != "verify"
      SshCheck::Result.new(success: ok, message: ok ? "ok" : "Clé SSH refusée par le serveur", details: "x")
    end

    def remove(server, blob, protected_keys:, key:, **)
      @removals << [ server.name, blob, protected_keys.map(&:state), key.state ]
      ok = @failures[server.name] != "cleanup"
      AuthorizedKeyRemoval::Result.new(status: ok ? :removed : :error, error_title: "Connexion impossible", error_details: "x")
    end
  end

  def run_job(rotation, fake, **options)
    stub_method(SshConnection, :open, ->(server, **kw, &block) { fake.open(server, **kw, &block) }) do
      stub_method(SshCheck, :call, ->(server, **kw) { fake.check(server, **kw) }) do
        stub_method(AuthorizedKeyRemoval, :call, ->(server, blob, **kw) { fake.remove(server, blob, **kw) }) do
          RotateSshKeyJob.perform_now(rotation, **options)
        end
      end
    end
  end

  setup do
    @rotation = KeyRotation.start!(by: users(:one))
  end

  test "installs with the old key, checks with the new one, removes the old one, then activates" do
    fake = FakeServers.new
    old_blob = ssh_keys(:main).blob

    run_job(@rotation, fake)

    assert_equal %w[Backup Database Web], fake.installs.map(&:first)
    assert fake.installs.all? { |_, states| states == %w[active pending] }
    assert fake.checks.all? { |_, state| state == "pending" }
    assert fake.removals.all? { |_, blob, protected, key| blob == old_blob && protected == [ "pending" ] && key == "pending" }
    assert_equal %w[rotated] * 3, @rotation.steps.reload.map(&:status)
    assert_equal :activated, @rotation.reload.status
    assert_equal [ @rotation.new_key ], SshKey.app_keys
  end

  test "records the phase that failed and keeps both keys" do
    fake = FakeServers.new("Backup" => "install", "Database" => "verify", "Web" => "cleanup")

    run_job(@rotation, fake)

    assert_equal [ [ "Backup", "install" ], [ "Database", "verify" ], [ "Web", "cleanup" ] ], @rotation.steps.reload.map { |s| [ s.server_name, s.phase ] }
    assert_equal [ %w[Database Web], %w[Web] ], [ fake.checks.map(&:first), fake.removals.map(&:first) ]
    assert_equal :partial, @rotation.reload.status
    assert_equal 2, SshKey.app_keys.size
  end

  test "retrying redoes only the failed servers" do
    run_job(@rotation, FakeServers.new("Database" => "verify"))
    fake = FakeServers.new

    run_job(@rotation, fake, retry_failed: true)

    assert_equal [ "Database" ], fake.installs.map(&:first)
    assert_equal %w[rotated] * 3, @rotation.steps.reload.map(&:status)
    assert_equal :activated, @rotation.reload.status
  end
end
