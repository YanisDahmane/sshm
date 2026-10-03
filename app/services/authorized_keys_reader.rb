# Reads the authorized_keys file of an account (see AuthorizedKeysAccount) and
# parses it into AuthorizedKey objects. A missing file means no keys. Never
# raises: failures are returned in the Result.
class AuthorizedKeysReader
  Result = Data.define(:keys, :error_title, :error_details, :reason) do
    def initialize(keys:, error_title:, error_details:, reason: nil) = super
    def success? = error_title.nil?
  end

  def self.call(server, account: nil, **connection_options)
    account ||= AuthorizedKeysAccount.login(server)
    output = SshConnection.open(server, **connection_options) do |ssh|
      ssh.exec!(account.command(read_script(account.home))).stdout
    end

    Result.new(keys: AuthorizedKey.parse(output), error_title: nil, error_details: nil)
  rescue SshConnection::Error => e
    title, details = account.error_for(e)
    Result.new(keys: [], error_title: title, error_details: details, reason: e.reason)
  end

  def self.read_script(home)
    AuthorizedKeysScript.prelude(home) + <<~SH
      file="$home/.ssh/authorized_keys"
      if [ -f "$file" ]; then cat "$file"; fi
    SH
  end
end
