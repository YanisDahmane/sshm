# Removes a key from a server account from the UI (see Keys::AuthorizedKeyRemoval)
# and keeps Elio in sync: ends its temporary accesses, drops it from the
# account snapshot and logs a key_removed activity.
class Keys::Revocation
  def self.call(server, blob, account:, key_name: nil, public_key: nil, **connection_options)
    result = Keys::AuthorizedKeyRemoval.call(server, blob, account: account, **connection_options)
    return result unless result.success?

    TemporaryAccess.active.where(server: server, unix_user: account.unix_user, key_blob: blob).find_each(&:end!)
    AccountSnapshot.find_by(server: server, unix_user: account.unix_user)&.forget!(blob)
    Activity.record!(:key_removed, server: server, public_key: public_key, unix_user: account.unix_user, key_name: key_name) if result.removed?
    result
  end
end
