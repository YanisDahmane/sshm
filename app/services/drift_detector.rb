# Compares the access rules with the last keys read on each account they
# cover (AccountSnapshot): profiles whose key is missing, and keys present
# that no rule expects ("extra"). Accounts covered by no rule are not managed
# and never reported; SSHM's keys and active temporary accesses are never
# extra. Keys are compared by fingerprint (comment and options ignored).
class DriftDetector
  Entry = Data.define(:server, :unix_user, :snapshot, :expected, :missing, :extra) do
    def scanned? = !snapshot.nil?
    def drift? = missing.any? || extra.any?
    def account = AuthorizedKeysAccount.for(server, unix_user)
    def profile_for(key) = expected[key.fingerprint] || Profile.find_by(fingerprint: key.fingerprint)
  end

  Report = Data.define(:entries) do
    def drifts = entries.select(&:drift?)
    def unscanned = entries.reject(&:scanned?)
    def missing_count = entries.sum { |entry| entry.missing.size }
    def extra_count = entries.sum { |entry| entry.extra.size }
    def clean? = drifts.empty?
    def entry_for(server, unix_user) = entries.find { |entry| entry.server == server && entry.unix_user == unix_user }

    # Identifies the current set of differences (used to notify only changes).
    def signature
      drifts.flat_map do |entry|
        entry.missing.map { |profile| "+#{entry.server.id}:#{entry.unix_user}:#{profile.fingerprint}" } +
          entry.extra.map { |key| "-#{entry.server.id}:#{entry.unix_user}:#{key.fingerprint}" }
      end.sort
    end
  end

  def self.call
    expectations = AccessRule.expectations
    snapshots = AccountSnapshot.where(server_id: expectations.keys.map { |server, _| server.id }.uniq).index_by { |snapshot| [ snapshot.server_id, snapshot.unix_user ] }
    temporary = TemporaryAccess.active.pluck(:server_id, :unix_user, :fingerprint).to_set
    app_keys = SshKey.app_keys

    entries = expectations.map do |(server, unix_user), expected|
      snapshot = snapshots[[ server.id, unix_user ]]
      next Entry.new(server, unix_user, nil, expected, [], []) unless snapshot

      present = snapshot.fingerprints.to_set
      missing = expected.reject { |fingerprint, _| present.include?(fingerprint) }.values.sort_by(&:name)
      extra = snapshot.keys.reject do |key|
        expected.key?(key.fingerprint) || key.matches?(app_keys) || temporary.include?([ server.id, unix_user, key.fingerprint ])
      end
      Entry.new(server, unix_user, snapshot, expected, missing, extra.uniq(&:fingerprint))
    end

    Report.new(entries.sort_by { |entry| [ entry.server.name.downcase, entry.unix_user ] })
  end
end
