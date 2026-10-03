require "test_helper"
require "open3"

class SshKeyGeneratorTest < ActiveSupport::TestCase
  setup do
    @key = SshKeyGenerator.generate(comment: "sshm-test")
  end

  test "public key is a single OpenSSH ed25519 line with the comment" do
    type, blob, comment = @key.public_key.split(" ")

    assert_equal "ssh-ed25519", type
    assert_equal "sshm-test", comment
    assert_equal 51, Base64.strict_decode64(blob).bytesize
    assert_no_match "\n", @key.public_key
  end

  test "private key is an unencrypted OpenSSH private key block" do
    assert @key.private_key.start_with?("-----BEGIN OPENSSH PRIVATE KEY-----\n")
    assert @key.private_key.end_with?("-----END OPENSSH PRIVATE KEY-----\n")
    assert @key.private_key.lines[1..-2].all? { |line| line.chomp.length <= 70 }
  end

  test "Net::SSH loads the private key and derives the same public key" do
    private_key = Net::SSH::KeyFactory.load_data_private_key(@key.private_key)
    public_blob = Base64.strict_decode64(@key.public_key.split(" ")[1])

    assert_equal "ssh-ed25519", private_key.ssh_type
    assert_equal public_blob, private_key.public_key.to_blob
  end

  test "signatures made with the private key verify with the public key" do
    private_key = Net::SSH::KeyFactory.load_data_private_key(@key.private_key)
    public_key = Net::SSH::KeyFactory.load_data_public_key(@key.public_key)

    signature = private_key.ssh_do_sign("payload")
    assert public_key.ssh_do_verify(signature, "payload")
    assert_raises(Ed25519::VerifyError) { public_key.ssh_do_verify(signature, "tampered") }
  end

  test "fingerprint is the SHA256 fingerprint of the public key" do
    public_blob = Base64.strict_decode64(@key.public_key.split(" ")[1])

    assert_match %r{\ASHA256:[A-Za-z0-9+/]{43}\z}, @key.fingerprint
    assert_equal "SHA256:#{Base64.strict_encode64(Digest::SHA256.digest(public_blob)).delete("=")}", @key.fingerprint
  end

  test "each call generates a different key pair" do
    other = SshKeyGenerator.generate
    assert_not_equal @key.public_key, other.public_key
    assert_not_equal @key.private_key, other.private_key
  end

  test "ssh-keygen accepts the private key and agrees on the fingerprint" do
    skip "ssh-keygen not installed" unless system("which ssh-keygen > /dev/null 2>&1")

    Dir.mktmpdir do |dir|
      path = File.join(dir, "id_ed25519")
      File.write(path, @key.private_key, perm: 0o600)

      public_key, status = Open3.capture2("ssh-keygen", "-y", "-f", path)
      assert status.success?
      assert_equal @key.public_key.split(" ")[0, 2], public_key.split(" ")[0, 2]

      File.write("#{path}.pub", "#{@key.public_key}\n")
      fingerprint, status = Open3.capture2("ssh-keygen", "-l", "-f", "#{path}.pub")
      assert status.success?
      assert_equal @key.fingerprint, fingerprint.split(" ")[1]
    end
  end
end
