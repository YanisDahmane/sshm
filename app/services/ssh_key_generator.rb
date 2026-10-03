require "ed25519"
require "net/ssh"

# Generates an Ed25519 key pair in OpenSSH formats, without shelling out to
# ssh-keygen:
#   - public key:  "ssh-ed25519 AAAA... comment" (one line, for authorized_keys)
#   - private key: unencrypted "-----BEGIN OPENSSH PRIVATE KEY-----" block
#   - fingerprint: "SHA256:..." as printed by `ssh-keygen -l`
class SshKeyGenerator
  KEY_TYPE = "ssh-ed25519".freeze
  AUTH_MAGIC = "openssh-key-v1\0".b.freeze

  Result = Data.define(:public_key, :private_key, :fingerprint)

  def self.generate(comment: "sshm")
    signing_key = Ed25519::SigningKey.generate
    public_bytes = signing_key.verify_key.to_bytes
    public_blob = Net::SSH::Buffer.from(:string, KEY_TYPE, :string, public_bytes).to_s

    Result.new(
      public_key: "#{KEY_TYPE} #{Base64.strict_encode64(public_blob)} #{comment}",
      private_key: private_key_pem(public_blob, public_bytes, signing_key.keypair, comment),
      fingerprint: fingerprint(public_blob)
    )
  end

  # "SHA256:<unpadded base64 of the SHA-256 digest of the key blob>"
  def self.fingerprint(public_blob)
    "SHA256:#{Base64.strict_encode64(Digest::SHA256.digest(public_blob)).delete("=")}"
  end

  # Layout from https://github.com/openssh/openssh-portable/blob/master/PROTOCOL.key
  def self.private_key_pem(public_blob, public_bytes, keypair, comment)
    check = SecureRandom.random_bytes(4).unpack1("N")
    private_section = Net::SSH::Buffer.from(
      :long, check, :long, check,
      :string, KEY_TYPE, :string, public_bytes, :string, keypair, :string, comment
    ).to_s
    private_section += (1..(-private_section.bytesize % 8)).to_a.pack("C*")

    body = AUTH_MAGIC + Net::SSH::Buffer.from(
      :string, "none", :string, "none", :string, "",
      :long, 1, :string, public_blob, :string, private_section
    ).to_s

    [ "-----BEGIN OPENSSH PRIVATE KEY-----", *Base64.strict_encode64(body).scan(/.{1,70}/), "-----END OPENSSH PRIVATE KEY-----", "" ].join("\n")
  end
  private_class_method :private_key_pem
end
