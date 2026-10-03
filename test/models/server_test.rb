require "test_helper"

class ServerTest < ActiveSupport::TestCase
  def build_server(**attributes)
    Server.new({ name: "New", host: "10.0.0.1", username: "deploy" }.merge(attributes))
  end

  test "fixtures are valid" do
    assert servers(:web).valid?
    assert servers(:db).valid?
    assert servers(:backup).valid?
  end

  test "requires a name, a host and a username" do
    server = build_server(name: "", host: "", username: "")
    assert_not server.valid?
    assert server.errors.added?(:name, :blank)
    assert server.errors.added?(:host, :blank)
    assert server.errors.added?(:username, :blank)
  end

  test "name is unique, case insensitive" do
    server = build_server(name: "web")
    assert_not server.valid?
    assert server.errors.of_kind?(:name, :taken)
  end

  test "port defaults to 22" do
    assert_equal 22, Server.new.port
  end

  test "port must be an integer between 1 and 65535" do
    [ 0, 65_536, -1, 22.5, nil ].each do |port|
      assert_not build_server(port: port).valid?, "#{port.inspect} should be invalid"
    end
    [ 1, 22, 65_535 ].each do |port|
      assert build_server(port: port).valid?, "#{port} should be valid"
    end
  end

  test "host accepts IPv4, IPv6 and hostnames" do
    [ "192.168.1.10", "::1", "2001:db8::1", "example.com", "srv-01.internal.example.com", "localhost" ].each do |host|
      assert build_server(host: host).valid?, "#{host} should be valid"
    end
  end

  test "host rejects malformed values" do
    [ "not a host", "http://example.com", "-bad.com", "bad_host.com", "user@host" ].each do |host|
      server = build_server(host: host)
      assert_not server.valid?, "#{host} should be invalid"
      assert server.errors.added?(:host, :invalid)
    end
  end

  test "strips whitespace from name, host and username" do
    server = build_server(name: "  Spaced  ", host: " 10.0.0.2 ", username: " deploy ")
    assert_equal "Spaced", server.name
    assert_equal "10.0.0.2", server.host
    assert_equal "deploy", server.username
  end

  test "changing the host or port resets the reachability status" do
    server = servers(:web)
    server.update!(host: "10.0.0.99")
    assert_nil server.reachable
    assert_nil server.last_checked_at

    server = servers(:db)
    server.update!(port: 2200)
    assert_nil server.reachable
    assert_nil server.last_checked_at
  end

  test "changing other attributes keeps the reachability status" do
    server = servers(:web)
    server.update!(name: "Renamed", username: "ops")
    assert server.reachable
    assert_not_nil server.last_checked_at
  end

  test "record_ssh_status! stores the result without touching updated_at" do
    server = servers(:web)

    assert_no_changes -> { server.reload.updated_at } do
      server.record_ssh_status!(true)
    end
    assert server.ssh_ok
    assert_not_nil server.ssh_checked_at
  end

  test "changing the host resets the SSH status too" do
    server = servers(:web)
    server.record_ssh_status!(true)

    server.update!(host: "10.0.0.99")

    assert_nil server.ssh_ok
    assert_nil server.ssh_checked_at
  end
end
