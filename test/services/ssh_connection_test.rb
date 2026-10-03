require "test_helper"

class SshConnectionTest < ActiveSupport::TestCase
  include TcpHelpers

  setup do
    @known_hosts = Rails.root.join("tmp", "test", "ssh-#{SecureRandom.hex(4)}", "known_hosts")
  end

  teardown do
    FileUtils.rm_rf(@known_hosts.dirname)
  end

  def connect(server, fake, &block)
    SshConnection.open(server, transport: fake, known_hosts_file: @known_hosts, timeout: 5, &block)
  end

  test "connects with the server address, port and username" do
    fake = FakeSsh.new
    connect(servers(:db), fake) { }

    assert_equal "db.example.com", fake.started_with[:host]
    assert_equal "admin", fake.started_with[:user]
    assert_equal 2222, fake.started_with[:port]
    assert_equal 5, fake.started_with[:timeout]
  end

  test "authenticates only with the app SSH key" do
    fake = FakeSsh.new
    connect(servers(:web), fake) { }

    assert_equal %w[publickey], fake.started_with[:auth_methods]
    assert_equal [ ssh_keys(:main).private_key ], fake.started_with[:key_data]
    assert_equal [], fake.started_with[:keys]
    assert fake.started_with[:keys_only]
    assert_equal false, fake.started_with[:use_agent]
    assert_nil fake.started_with[:password]
  end

  test "uses the given key instead of the current one" do
    other = SshKey.new(private_key: "other-private-key")
    fake = FakeSsh.new
    SshConnection.open(servers(:web), key: other, transport: fake, known_hosts_file: @known_hosts) { }

    assert_equal [ "other-private-key" ], fake.started_with[:key_data]
  end

  test "raises MissingKeyError when no SSH key is configured" do
    SshKey.delete_all
    fake = FakeSsh.new

    error = assert_raises(SshConnection::MissingKeyError) { connect(servers(:web), fake) { } }
    assert_match "paramètres", error.message
    assert_nil fake.started_with
  end

  test "never prompts and pins host keys in the app known_hosts file" do
    fake = FakeSsh.new
    connect(servers(:web), fake) { }

    assert fake.started_with[:non_interactive]
    assert_equal false, fake.started_with[:config]
    assert_equal :accept_new, fake.started_with[:verify_host_key]
    assert_equal @known_hosts.to_s, fake.started_with[:user_known_hosts_file]
    assert_equal [], fake.started_with[:global_known_hosts_file]
    assert @known_hosts.dirname.directory?
  end

  test "returns the value of the block" do
    assert_equal :done, connect(servers(:web), FakeSsh.new) { :done }
  end

  test "exec returns stdout, stderr and the exit status separately" do
    fake = FakeSsh.new(responses: { "uname" => FakeSsh::Response.new("Linux\n", "warning\n", 0) })

    result = connect(servers(:web), fake) { |ssh| ssh.exec("uname") }

    assert_equal SshConnection::Result.new(stdout: "Linux\n", stderr: "warning\n", exit_status: 0), result
    assert result.success?
  end

  test "exec does not raise on a failing command" do
    fake = FakeSsh.new(responses: { "cat /missing" => FakeSsh::Response.new("", "No such file or directory\n", 1) })

    result = connect(servers(:web), fake) { |ssh| ssh.exec("cat /missing") }

    assert_not result.success?
    assert_equal 1, result.exit_status
  end

  test "exec runs several commands in the same session" do
    fake = FakeSsh.new(responses: { "whoami" => FakeSsh::Response.new("deploy\n", "", 0), "hostname" => FakeSsh::Response.new("web\n", "", 0) })

    outputs = connect(servers(:web), fake) { |ssh| [ ssh.exec("whoami").stdout, ssh.exec("hostname").stdout ] }

    assert_equal [ "deploy\n", "web\n" ], outputs
    assert_equal %w[whoami hostname], fake.commands
  end

  test "exec! returns the result of a successful command" do
    fake = FakeSsh.new(responses: { "id -u" => FakeSsh::Response.new("0\n", "", 0) })

    assert_equal "0\n", connect(servers(:web), fake) { |ssh| ssh.exec!("id -u").stdout }
  end

  test "exec! raises CommandError with the result on failure" do
    fake = FakeSsh.new(responses: { "cat /missing" => FakeSsh::Response.new("", "No such file or directory\n", 1) })

    error = assert_raises(SshConnection::CommandError) do
      connect(servers(:web), fake) { |ssh| ssh.exec!("cat /missing") }
    end
    assert_equal "`cat /missing` exited with status 1: No such file or directory", error.message
    assert_equal 1, error.result.exit_status
  end

  test "exec outside of an open session raises" do
    ssh = SshConnection.new(servers(:web), transport: FakeSsh.new)
    assert_raises(SshConnection::Error) { ssh.exec("uname") }
  end

  test "the session is not usable after the block" do
    ssh = connect(servers(:web), FakeSsh.new) { |connection| connection }
    assert_raises(SshConnection::Error) { ssh.exec("uname") }
  end

  test "wraps authentication failures" do
    fake = FakeSsh.new(error: Net::SSH::AuthenticationFailed.new("Authentication failed for user deploy@192.168.1.10"))

    error = assert_raises(SshConnection::AuthenticationError) { connect(servers(:web), fake) { } }
    assert_match "deploy@192.168.1.10", error.message
  end

  test "wraps host key mismatches" do
    mismatch = Net::SSH::HostKeyMismatch.new("fingerprint does not match")
    mismatch.data = { fingerprint: "SHA256:abc" }
    fake = FakeSsh.new(error: mismatch)

    error = assert_raises(SshConnection::HostKeyMismatchError) { connect(servers(:web), fake) { } }
    assert_match "SHA256:abc", error.message
  end

  test "each error has a French title" do
    assert_equal "Connexion impossible", SshConnection::ConnectionError.new.title
    assert_equal "Clé SSH refusée par le serveur", SshConnection::AuthenticationError.new.title
    assert_equal "L'empreinte du serveur a changé", SshConnection::HostKeyMismatchError.new.title
    assert_equal "Aucune clé SSH configurée", SshConnection::MissingKeyError.new.title
    assert_equal "Erreur SSH", SshConnection::Error.new.title
  end

  test "all errors share a common base class" do
    [ SshConnection::ConnectionError, SshConnection::AuthenticationError, SshConnection::HostKeyMismatchError, SshConnection::MissingKeyError, SshConnection::CommandError ].each do |klass|
      assert_operator klass, :<, SshConnection::Error
    end
  end

  # The tests below go through the real Net::SSH against local sockets.

  test "raises ConnectionError when the port is closed" do
    server = servers(:web)
    server.assign_attributes(host: "127.0.0.1", port: closed_port)

    error = assert_raises(SshConnection::ConnectionError) do
      SshConnection.open(server, known_hosts_file: @known_hosts, timeout: 2) { }
    end
    assert_match "127.0.0.1:#{server.port}", error.message
  end

  test "raises ConnectionError when the host does not speak SSH" do
    with_banner_server("HTTP/1.1 400 Bad Request\r\n\r\n") do |port|
      server = servers(:web)
      server.assign_attributes(host: "127.0.0.1", port: port)

      assert_raises(SshConnection::ConnectionError) do
        SshConnection.open(server, known_hosts_file: @known_hosts, timeout: 2) { }
      end
    end
  end

  test "raises ConnectionError when the host never answers" do
    with_open_port do |port|
      server = servers(:web)
      server.assign_attributes(host: "127.0.0.1", port: port)

      started = Time.current
      assert_raises(SshConnection::ConnectionError) do
        SshConnection.open(server, known_hosts_file: @known_hosts, timeout: 1) { }
      end
      assert_operator Time.current - started, :<, 5
    end
  end

  private

  # Accepts one connection, writes `banner`, then closes it.
  def with_banner_server(banner)
    listener = TCPServer.new("127.0.0.1", 0)
    thread = Thread.new do
      client = listener.accept
      client.write(banner)
      client.close
    rescue IOError
      nil
    end
    yield listener.addr[1]
  ensure
    listener&.close
    thread&.join(1)
  end

  test "tries the active then the pending app key" do
    pending = SshKey.generate_pending!
    fake = FakeSsh.new
    connect(servers(:web), fake) { }

    assert_equal [ ssh_keys(:main).private_key, pending.private_key ], fake.started_with[:key_data]
  end

  test "accepts an explicit list of keys" do
    other = SshKey.new(private_key: "other")
    fake = FakeSsh.new
    SshConnection.open(servers(:web), key: [ other, nil ], transport: fake, known_hosts_file: @known_hosts) { }

    assert_equal [ "other" ], fake.started_with[:key_data]
  end
end
