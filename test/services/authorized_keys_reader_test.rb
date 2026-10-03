require "test_helper"

class AuthorizedKeysReaderTest < ActiveSupport::TestCase
  include LocalShellHelpers

  setup do
    @known_hosts = Rails.root.join("tmp", "test", "ssh-#{SecureRandom.hex(4)}", "known_hosts")
    setup_temp_home
  end

  teardown do
    FileUtils.rm_rf(@known_hosts.dirname)
    teardown_temp_home
  end

  def read(fake, account: nil)
    AuthorizedKeysReader.call(servers(:web), account: account, transport: fake, known_hosts_file: @known_hosts)
  end

  test "reads and parses the SSH user's authorized_keys" do
    authorized_keys_file.dirname.mkpath
    authorized_keys_file.write("#{ssh_keys(:main).public_key}\n#{SshKeyGenerator.generate(comment: "").public_key.strip}\n")

    result = read(FakeSsh.new(handler: local_shell))

    assert result.success?
    assert_equal [ "sshm-fixture", nil ], result.keys.map(&:name)
  end

  test "returns no keys when the file does not exist" do
    result = read(FakeSsh.new(handler: local_shell))

    assert result.success?
    assert_empty result.keys
  end

  test "returns an error when the file cannot be read" do
    authorized_keys_file.dirname.mkpath
    authorized_keys_file.write("x")
    authorized_keys_file.chmod(0o000)

    result = read(FakeSsh.new(handler: local_shell))

    assert_not result.success?
    assert_equal "La commande a échoué", result.error_title
    assert_match "Permission denied", result.error_details
  ensure
    authorized_keys_file.chmod(0o600)
  end

  test "reads root's file through sudo" do
    fake = FakeSsh.new(handler: ->(_command) { FakeSsh::Response.new("#{profiles(:alice).public_key}\n", "", 0) })

    result = read(fake, account: AuthorizedKeysAccount.for(servers(:web), "root"))

    assert_equal [ "alice@laptop" ], result.keys.map(&:name)
    *prefix, script = Shellwords.split(fake.commands.sole)
    assert_equal %w[sudo -n sh -c], prefix
    assert_includes script.lines, "home=~root\n"
  end

  test "explains when sudo is not available for root" do
    fake = FakeSsh.new(handler: ->(_command) { FakeSsh::Response.new("", "sudo: a password is required\n", 1) })

    result = read(fake, account: AuthorizedKeysAccount.for(servers(:web), "root"))

    assert_not result.success?
    assert_equal "Accès root impossible", result.error_title
    assert_match "deploy doit pouvoir lancer sudo sans mot de passe", result.error_details
  end

  test "returns the SSH error when the connection fails" do
    result = read(FakeSsh.new(error: Net::SSH::AuthenticationFailed.new("Authentication failed for user deploy@192.168.1.10")))

    assert_not result.success?
    assert_equal "Clé SSH refusée par le serveur", result.error_title
    assert_match "deploy@192.168.1.10", result.error_details
  end

  test "returns an error when no SSH key is configured" do
    SshKey.delete_all

    result = read(FakeSsh.new)

    assert_equal "Aucune clé SSH configurée", result.error_title
  end

  test "explains an unknown user (the script stops when ~user does not expand)" do
    fake = FakeSsh.new(handler: local_shell)

    result = read(fake, account: AuthorizedKeysAccount.for(servers(:web).tap { |server| server.username = "root" }, "nosuchuser#{SecureRandom.hex(2)}"))

    assert_equal "Utilisateur inconnu", result.error_title
  end
end
