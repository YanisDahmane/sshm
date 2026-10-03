# The key pair the app uses to connect to every server. Its public key must be
# added to the servers' authorized_keys. There is at most one key at a time.
class SshKey < ApplicationRecord
  encrypts :private_key

  validates :public_key, :private_key, :fingerprint, presence: true

  def self.current
    order(:created_at).last
  end

  # Replaces the current key with a freshly generated one.
  def self.generate!(comment: "sshm")
    key = SshKeyGenerator.generate(comment: comment)

    transaction do
      delete_all
      create!(public_key: key.public_key, private_key: key.private_key, fingerprint: key.fingerprint)
    end
  end
end
