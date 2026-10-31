# Reads the authorized keys of a server (login account) and refreshes its
# AccountSnapshot and the server's SSH status. Never raises.
class Keys::ServerScan
  Result = Data.define(:error_title) do
    def success? = error_title.nil?
  end

  def self.call(server, **connection_options)
    account = AuthorizedKeysAccount.login(server)
    read = Keys::AuthorizedKeysReader.call(server, account: account, **connection_options)

    if read.success?
      server.record_ssh_status!(true)
      AccountSnapshot.record!(server, account, read.keys)
    elsif read.reason == :key_refused
      server.record_ssh_status!(false)
    end
    Result.new(error_title: read.error_title)
  end
end
