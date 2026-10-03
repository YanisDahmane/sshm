module TemporaryAccessHelpers
  # Creates an active TemporaryAccess for `profile` on `server`'s `unix_user`.
  def create_temporary_access(profile: profiles(:ci), server: servers(:web), unix_user: "deploy", expires_at: 9.minutes.from_now)
    TemporaryAccess.create!(server: server, profile: profile, unix_user: unix_user, key_blob: profile.authorized_key.key,
                            fingerprint: profile.fingerprint, expires_at: expires_at)
  end
end
