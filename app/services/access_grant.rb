# Grants a profile access to a server account, permanently or for a limited
# time (see TemporaryAccess), and keeps the temporary accesses in sync:
#
# - a temporary grant records a TemporaryAccess and schedules its expiry;
# - any new grant for a key that has an active temporary access replaces its
#   authorized_keys line (to change or drop the expiry) and ends the old access;
# - a key already authorized permanently stays as it is.
class AccessGrant
  def self.call(server, profile, account:, duration: nil, **connection_options)
    active = TemporaryAccess.active.find_by(server: server, unix_user: account.unix_user, fingerprint: profile.fingerprint)
    expires_at = duration && Time.current + duration

    result = ProfileAuthorization.call(server, profile, account: account, expires_at: expires_at, replace: active.present?, **connection_options)
    return result unless result.success?

    TemporaryAccess.transaction do
      active&.end!
      schedule_expiry(server, profile, account, expires_at) if expires_at && result.added?
    end
    result
  end

  def self.schedule_expiry(server, profile, account, expires_at)
    access = TemporaryAccess.create!(server: server, profile: profile, unix_user: account.unix_user,
                                     key_blob: profile.authorized_key.key, fingerprint: profile.fingerprint, expires_at: expires_at)
    ExpireTemporaryAccessJob.set(wait_until: expires_at).perform_later(access)
  end
  private_class_method :schedule_expiry
end
