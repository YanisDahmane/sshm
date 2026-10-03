# Grants or revokes several profiles on several servers, one after the other,
# on the login user of each server or on the same named account everywhere.
# Used by the profile page (one profile) and the team page (its members).
# Never raises: each (server, profile) outcome is returned as a Result.
class BulkAccess
  Result = Data.define(:server, :profile, :unix_user, :status, :message) do
    def error? = status == :error
  end

  def self.grant(profiles, servers, account: nil, duration: nil)
    each_account(servers, account) do |server, target, results|
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

  def self.revoke(profiles, servers, account: nil)
    each_account(servers, account) do |server, target, results|
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

  # Yields each server with its target account; an invalid account name is
  # reported for every profile instead.
  def self.each_account(servers, account)
    servers.each_with_object([]) do |server, results|
      target = begin
        account.present? ? AuthorizedKeysAccount.for(server, account.strip) : AuthorizedKeysAccount.login(server)
      rescue ArgumentError
        results << Result.new(server, nil, account, :error, "Nom de compte invalide")
        next
      end
      yield server, target, results
    end
  end
  private_class_method :each_account

  def self.refresh_snapshot(server, account)
    read = AuthorizedKeysReader.call(server, account: account)
    AccountSnapshot.record!(server, account, read.keys) if read.success?
  end
  private_class_method :refresh_snapshot
end
