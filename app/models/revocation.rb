# Removal of a profile's key from every account of every server ("révoquer
# partout"), run by RevokeProfileEverywhereJob. Keeps the profile's name and
# key so it can outlive the profile (which can be deleted at the end).
class Revocation < ApplicationRecord
  belongs_to :profile, optional: true
  belongs_to :started_by, class_name: "User", optional: true
  has_many :steps, -> { order(:server_name, :unix_user) }, class_name: "RevocationStep", dependent: :delete_all

  validates :profile_name, :fingerprint, :key_blob, presence: true

  def self.start!(profile, by:, delete_profile: false)
    create!(profile: profile, profile_name: profile.name, fingerprint: profile.fingerprint, key_blob: profile.authorized_key.key,
            started_by: by, delete_profile: delete_profile, servers_count: Server.count)
  end

  def running? = finished_at.nil?

  def servers_done = steps.distinct.count(:server_name)

  def removed_count = steps.removed.count

  def failed_count = steps.failed.count

  def status
    if running? then :running
    elsif failed_count.zero? then :succeeded
    else :partial
    end
  end

  # Closes the run: logs it and deletes the profile when asked and nothing failed.
  def finish!
    update!(finished_at: Time.current)
    Activity.record!(:profile_revoked_everywhere, profile: profile, profile_name: profile_name, fingerprint: fingerprint,
                                                  removed: removed_count, failed: failed_count)
    return unless delete_profile && failed_count.zero? && profile

    deleted = profile
    deleted.destroy!
    Activity.record!(:profile_deleted, profile_name: deleted.name, fingerprint: deleted.fingerprint)
  end
end
