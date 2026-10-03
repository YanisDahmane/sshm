# Last known authorized keys of a server account, as read over SSH. Keeps the
# dashboard figures and "where does this profile have access?" answerable
# without connecting to every server. Refreshed on each successful read
# (key list, ServerScan) and when an expired key is removed.
class AccountSnapshot < ApplicationRecord
  belongs_to :server

  validates :unix_user, :read_at, presence: true

  def self.record!(server, account, keys)
    snapshot = find_or_initialize_by(server: server, unix_user: account.unix_user)
    snapshot.update!(content: keys.map(&:to_line).join("\n"), read_at: Time.current)
    snapshot
  end

  # Snapshots holding the key with this fingerprint.
  def self.with_fingerprint(fingerprint)
    includes(:server).select { |snapshot| snapshot.fingerprints.include?(fingerprint) }
  end

  def account = AuthorizedKeysAccount.for(server, unix_user)

  def keys
    @keys ||= AuthorizedKey.parse(content)
  end

  def fingerprints = keys.map(&:fingerprint)

  # Keys that match no profile (named or not), except SSHM's own key.
  def keys_without_profile(profile_fingerprints:, app_key:)
    keys.reject { |key| key.matches?(app_key) || profile_fingerprints.include?(key.fingerprint) }
  end

  # Drops a key removed from the server (e.g. an expired temporary access).
  def forget!(blob)
    update!(content: keys.reject { |key| key.key == blob }.map(&:to_line).join("\n"))
  end

  def content=(value)
    @keys = nil
    super
  end
end
