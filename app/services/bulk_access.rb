# Adds several keyring keys to several servers (on the login user of each),
# a few servers at a time (BoundedParallel), the keys of one server one after
# the other. Used by the keyring key page.
# Never raises: each (server, public_key) outcome is returned as a Result, in
# the servers' order.
class BulkAccess
  Result = Data.define(:server, :public_key, :unix_user, :status, :message) do
    def error? = status == :error
  end

  def self.grant(public_keys, servers, duration: nil)
    BoundedParallel.map(servers) { |server| grant_on(server, public_keys, duration) }.flatten
  end

  def self.grant_on(server, public_keys, duration)
    account = AuthorizedKeysAccount.login(server)
    results = public_keys.map do |public_key|
      outcome = AccessGrant.call(server, public_key, account: account, duration: duration)
      message = if outcome.added? then duration ? "ajoutée pendant #{TemporaryAccess.label_for(duration)}" : "ajoutée"
      elsif outcome.already_present? then "déjà présente"
      else "#{outcome.error_title} — #{outcome.error_details}"
      end
      Result.new(server, public_key, account.unix_user, outcome.status, message)
    end
    refresh_snapshot(server, account) unless results.all?(&:error?)
    results
  end
  private_class_method :grant_on

  def self.refresh_snapshot(server, account)
    read = AuthorizedKeysReader.call(server, account: account)
    AccountSnapshot.record!(server, account, read.keys) if read.success?
  end
  private_class_method :refresh_snapshot
end
