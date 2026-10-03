# Reads the authorized keys of every account of a server and refreshes their
# AccountSnapshot and the server's SSH status. Never raises.
class ServerScan
  Result = Data.define(:accounts, :error_title) do
    def success? = error_title.nil?
  end

  def self.call(server, **connection_options)
    discovery = ServerAccountsReader.call(server, **connection_options)
    unless discovery.success?
      server.record_ssh_status!(false) if discovery.reason == :key_refused
      return Result.new(accounts: [], error_title: discovery.error_title)
    end

    server.record_ssh_status!(true)
    scanned = discovery.accounts.select do |account|
      read = AuthorizedKeysReader.call(server, account: account, **connection_options)
      AccountSnapshot.record!(server, account, read.keys) if read.success?
      read.success?
    end
    Result.new(accounts: scanned, error_title: nil)
  end
end
