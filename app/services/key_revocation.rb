# Removes a key from a server account from the UI (see AuthorizedKeyRemoval)
# and keeps SSHM in sync: ends its temporary accesses, drops it from the
# account snapshot and logs a key_removed activity.
class KeyRevocation
  def self.call(server, blob, account:, key_name: nil, profile: nil, **connection_options)
    result = AuthorizedKeyRemoval.call(server, blob, account: account, **connection_options)
    return result unless result.success?

    TemporaryAccess.active.where(server: server, unix_user: account.unix_user, key_blob: blob).find_each(&:end!)
    AccountSnapshot.find_by(server: server, unix_user: account.unix_user)&.forget!(blob)
    Activity.record!(:key_removed, server: server, profile: profile, unix_user: account.unix_user, key_name: key_name) if result.removed?
    result
  end
end
