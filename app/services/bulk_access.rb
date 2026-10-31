# Grants or revokes several profiles on several servers, one after the other,
# on the login user of each server. Used by the profile page.
# Never raises: each (server, profile) outcome is returned as a Result.
class BulkAccess
  Result = Data.define(:server, :profile, :unix_user, :status, :message) do
    def error? = status == :error
  end

  def self.grant(profiles, servers, duration: nil)
    each_account(servers) do |server, target, results|
      granted = false
      profiles.each do |profile|
        outcome = AccessGrant.call(server, profile, account: target, duration: duration)
        granted ||= outcome.success?
        message = if outcome.added? then duration ? "autorisé pendant #{TemporaryAccess.label_for(duration)}" : "autorisé"
        elsif outcome.already_present? then "déjà autorisé"
        else "#{outcome.error_title} — #{outcome.error_details}"
        end
        results << Result.new(server, profile, target.unix_user, outcome.status, message)
      end
      refresh_snapshot(server, target) if granted
    end
  end

  def self.revoke(profiles, servers)
    each_account(servers) do |server, target, results|
      profiles.each do |profile|
        key = profile.authorized_key
        outcome = KeyRevocation.call(server, key.key, account: target, key_name: key.comment || profile.name, profile: profile)
        message = if outcome.removed? then "retiré"
        elsif outcome.success? then "n'avait pas accès"
        else "#{outcome.error_title} — #{outcome.error_details}"
        end
        results << Result.new(server, profile, target.unix_user, outcome.status, message)
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
