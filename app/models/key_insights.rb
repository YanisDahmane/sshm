# Figures computed from the AccountSnapshots (last known keys of each server
# account): keys that match no profile ("orphans"), per server and in total.
class KeyInsights
  def initialize(snapshots: AccountSnapshot.includes(:server).to_a, app_key: SshKey.current)
    @snapshots = snapshots
    @app_key = app_key
    @profile_fingerprints = Profile.pluck(:fingerprint).to_set
  end

  def scanned? = @snapshots.any?

  def last_read_at = @snapshots.map(&:read_at).max

  def orphan_count = orphans_by_server_id.values.sum(&:size)

  # { server_id => orphan keys (one per fingerprint, whatever the account) }, only for scanned servers.
  def orphans_by_server_id
    @orphans_by_server_id ||= @snapshots.group_by(&:server_id).transform_values do |snapshots|
      snapshots.flat_map { |snapshot| snapshot.keys_without_profile(profile_fingerprints: @profile_fingerprints, app_key: @app_key) }
               .uniq(&:fingerprint)
    end
  end
end
