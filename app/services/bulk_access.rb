# Grants or revokes several keyring keys on several servers, one after the other,
# on the login user of each server. Used by the keyring key page.
# Never raises: each (server, public_key) outcome is returned as a Result.
class BulkAccess
  Result = Data.define(:server, :public_key, :unix_user, :status, :message) do
    def error? = status == :error
  end

  def self.grant(public_keys, servers, duration: nil)
    each_account(servers) do |server, target, results|
      granted = false
      public_keys.each do |public_key|
        outcome = AccessGrant.call(server, public_key, account: target, duration: duration)
        granted ||= outcome.success?
        message = if outcome.added? then duration ? "ajoutée pendant #{TemporaryAccess.label_for(duration)}" : "ajoutée"
        elsif outcome.already_present? then "déjà présente"
        else "#{outcome.error_title} — #{outcome.error_details}"
        end
        results << Result.new(server, public_key, target.unix_user, outcome.status, message)
      end
      refresh_snapshot(server, target) if granted
    end
  end

  def self.revoke(public_keys, servers)
    each_account(servers) do |server, target, results|
      public_keys.each do |public_key|
        key = public_key.authorized_key
        outcome = KeyRevocation.call(server, key.key, account: target, key_name: key.comment || public_key.name, public_key: public_key)
        message = if outcome.removed? then "retiré"
        elsif outcome.success? then "n'avait pas accès"
        else "#{outcome.error_title} — #{outcome.error_details}"
        end
        results << Result.new(server, public_key, target.unix_user, outcome.status, message)
      end
    end
  end

  # Yields each server with its login account.
  def self.each_account(servers)
    servers.each_with_object([]) do |server, results|
      yield server, AuthorizedKeysAccount.login(server), results
    end
  end
  private_class_method :each_account

  def self.refresh_snapshot(server, account)
    read = AuthorizedKeysReader.call(server, account: account)
    AccountSnapshot.record!(server, account, read.keys) if read.success?
  end
  private_class_method :refresh_snapshot
end
