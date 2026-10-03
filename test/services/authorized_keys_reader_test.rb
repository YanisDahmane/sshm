require "test_helper"

class AuthorizedKeysReaderTest < ActiveSupport::TestCase
  setup do
    @known_hosts = Rails.root.join("tmp", "test", "ssh-#{SecureRandom.hex(4)}", "known_hosts")
  end

  teardown do
    FileUtils.rm_rf(@known_hosts.dirname)
  end

  def read(fake)
    AuthorizedKeysReader.call(servers(:web), transport: fake, known_hosts_file: @known_hosts)
  end

  def cat_response(stdout: "", stderr: "", status: 0)
    { "cat ~/.ssh/authorized_keys" => FakeSsh::Response.new(stdout, stderr, status) }
  end

  test "reads and parses the SSH user's authorized_keys" do
    content = "#{ssh_keys(:main).public_key}\n#{SshKeyGenerator.generate(comment: "").public_key.strip}\n"
    fake = FakeSsh.new(responses: cat_response(stdout: content))

    result = read(fake)

    assert result.success?
    assert_equal [ "sshm-fixture", nil ], result.keys.map(&:name)
    assert_equal [ "cat ~/.ssh/authorized_keys" ], fake.commands
  end

  test "returns no keys when the file does not exist" do
    fake = FakeSsh.new(responses: cat_response(stderr: "cat: /home/deploy/.ssh/authorized_keys: No such file or directory\n", status: 1))

    result = read(fake)

    assert result.success?
    assert_empty result.keys
  end

  test "returns an error when the file cannot be read" do
    fake = FakeSsh.new(responses: cat_response(stderr: "cat: /home/deploy/.ssh/authorized_keys: Permission denied\n", status: 1))

    result = read(fake)

    assert_not result.success?
    assert_equal "Impossible de lire ~/.ssh/authorized_keys", result.error_title
    assert_match "Permission denied", result.error_details
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
end
