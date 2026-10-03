require "test_helper"

class ServerAccountsReaderTest < ActiveSupport::TestCase
  PASSWD = <<~PASSWD
    root:x:0:0:root:/root:/bin/bash
    daemon:x:1:1:daemon:/usr/sbin:/usr/sbin/nologin
    sshd:x:105:65534::/run/sshd:/usr/sbin/nologin
    zoe:x:1002:1002:Zoe,,,:/home/zoe:/bin/zsh
    deploy:x:1000:1000::/home/deploy:/bin/bash
    alice:x:1001:1001::/home/alice:/bin/bash
    backup:x:1003:1003::/home/backup:/usr/sbin/nologin
    ghost:x:1004:1004::/home/ghost:/bin/false
    nobody:x:65534:65534:nobody:/nonexistent:/bin/sh
    broken line
  PASSWD

  setup do
    @known_hosts = Rails.root.join("tmp", "test", "ssh-#{SecureRandom.hex(4)}", "known_hosts")
  end

  teardown do
    FileUtils.rm_rf(@known_hosts.dirname)
  end

  def read(fake, server: servers(:web))
    ServerAccountsReader.call(server, transport: fake, known_hosts_file: @known_hosts)
  end

  def passwd_response = ->(_command) { FakeSsh::Response.new(PASSWD, "", 0) }

  test "lists the login user, root, then human users with a shell" do
    result = read(FakeSsh.new(handler: passwd_response))

    assert result.success?
    assert_equal %w[deploy root alice zoe], result.accounts.map(&:unix_user)
  end

  test "lists root first when logging in as root" do
    server = servers(:web)
    server.username = "root"

    assert_equal %w[root alice deploy zoe], read(FakeSsh.new(handler: passwd_response), server: server).accounts.map(&:unix_user)
  end

  test "always includes the login user" do
    fake = FakeSsh.new(handler: ->(_command) { FakeSsh::Response.new("root:x:0:0::/root:/bin/sh\n", "", 0) })

    assert_equal %w[deploy root], read(fake).accounts.map(&:unix_user)
  end

  test "uses getent with a fallback to /etc/passwd" do
    fake = FakeSsh.new(handler: passwd_response)
    read(fake)
    assert_equal [ "getent passwd 2>/dev/null || cat /etc/passwd" ], fake.commands
  end

  test "falls back to the login user on error" do
    result = read(FakeSsh.new(error: Errno::ECONNREFUSED.new))

    assert_not result.success?
    assert_equal "Connexion impossible", result.error_title
    assert_equal %w[deploy], result.accounts.map(&:unix_user)
  end
end
