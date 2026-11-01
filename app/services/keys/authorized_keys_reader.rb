# Reads the authorized_keys file of an account (see AuthorizedKeysAccount) and
# parses it into AuthorizedKey objects. A missing file means no keys. Never
# raises: failures are returned in the Result.
class Keys::AuthorizedKeysReader
  Result = Data.define(:keys, :error_title, :error_details, :reason) do
    def initialize(keys:, error_title:, error_details:, reason: nil) = super
    def success? = error_title.nil?
  end

  def self.call(server, account: nil, **connection_options)
    account ||= AuthorizedKeysAccount.login(server)
    output = Ssh::Connection.open(server, **connection_options) do |ssh|
      ssh.run_command!("keys.read").stdout
    end

    Result.new(keys: AuthorizedKey.parse(output), error_title: nil, error_details: nil)
  rescue Ssh::Connection::Error => e
    title, details = account.error_for(e)
    Result.new(keys: [], error_title: title, error_details: details, reason: e.reason)
  end

  # The command sent (config/ssh_commands.yml: keys.read), also run locally by the tests.
  def self.command = Ssh::Commands.render("keys.read")
end
