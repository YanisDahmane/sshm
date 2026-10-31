# A person or machine (e.g. "Alice", "CI") identified by an SSH public key,
# that can be granted or denied access to servers.
class Profile < ApplicationRecord
  normalizes :name, with: ->(value) { value.squish }
  normalizes :public_key, with: ->(value) { value.strip }

  before_validation :set_fingerprint

  validates :name, presence: true, uniqueness: { case_sensitive: false }
  validates :public_key, presence: true
  validate :public_key_must_be_a_single_public_key
  validate :public_key_must_not_be_the_app_key
  validates :fingerprint, uniqueness: true, if: :authorized_key

  # The parsed key, or nil when public_key is not exactly one valid public key.
  def authorized_key
    keys = AuthorizedKey.parse(public_key)
    keys.sole if keys.one? && keys.first.options.nil? && !public_key.include?("\n")
  end

  private

  def set_fingerprint
    self.fingerprint = authorized_key&.fingerprint
  end

  def public_key_must_be_a_single_public_key
    return if public_key.blank? || authorized_key

    if public_key.include?("PRIVATE KEY")
      errors.add(:public_key, :private_key)
    else
      errors.add(:public_key, :invalid)
    end
  end

  def public_key_must_not_be_the_app_key
    errors.add(:public_key, :app_key) if authorized_key&.matches?(SshKey.app_keys)
  end
end
