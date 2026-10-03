require "test_helper"

class KnownHostsTest < ActiveSupport::TestCase
  setup do
    @file = Pathname(Dir.mktmpdir).join("known_hosts")
    @file.write(<<~HOSTS)
      192.168.1.10 ssh-ed25519 AAAAweb22
      [192.168.1.10]:2222 ssh-ed25519 AAAAweb2222
      db.example.com,10.0.0.2 ssh-ed25519 AAAAdb
      [db.example.com]:22 ssh-rsa AAAAdbrsa
      192.168.1.100 ssh-ed25519 AAAAother
    HOSTS
  end

  teardown { FileUtils.rm_rf(@file.dirname) }

  test "forgets a host on port 22, written with or without brackets" do
    assert_equal 2, KnownHosts.forget("db.example.com", 22, file: @file)

    assert_equal [ "AAAAweb22", "AAAAweb2222", "AAAAother" ], @file.readlines.map { |line| line.split.last }
  end

  test "forgets only the given port" do
    assert_equal 1, KnownHosts.forget("192.168.1.10", 2222, file: @file)

    assert_includes @file.read, "192.168.1.10 ssh-ed25519 AAAAweb22"
    assert_not_includes @file.read, "AAAAweb2222"
  end

  test "does not touch hosts that only start the same way" do
    KnownHosts.forget("192.168.1.10", 22, file: @file)
    assert_includes @file.read, "192.168.1.100 ssh-ed25519 AAAAother"
  end

  test "unknown host or missing file" do
    assert_equal 0, KnownHosts.forget("unknown.example.com", 22, file: @file)
    assert_equal 0, KnownHosts.forget("192.168.1.10", 22, file: @file.dirname.join("missing"))
  end
end
