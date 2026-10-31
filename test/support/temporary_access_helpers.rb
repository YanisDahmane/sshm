module TemporaryAccessHelpers
  # Creates an active TemporaryAccess for `public_key` on `server`'s `unix_user`.
  def create_temporary_access(public_key: public_keys(:ci), server: servers(:web), unix_user: "deploy", expires_at: 9.minutes.from_now)
    TemporaryAccess.create!(server: server, public_key: public_key, unix_user: unix_user, key_blob: public_key.authorized_key.key,
                            fingerprint: public_key.fingerprint, expires_at: expires_at)
  end
end
