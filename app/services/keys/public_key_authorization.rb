# Authorizes a keyring key on a server by appending its public key to the
# authorized_keys file of the login account (see AuthorizedKeysAccount), unless the
# key is already there. The line's comment is the key name in the keyring, so it shows
# up as "known". With `expires_at`, the line gets an OpenSSH `expiry-time`
# option (OpenSSH >= 8.2) so sshd refuses the key afterwards. With `replace`,
# existing lines for the key are removed first (to change or drop an expiry).
class Keys::PublicKeyAuthorization
  Result = Data.define(:status, :error_title, :error_details) do
    def success? = status != :error
    def added? = status == :added
    def already_present? = status == :already_present
  end

  def self.call(server, public_key, account: nil, expires_at: nil, replace: false, **connection_options)
    account ||= AuthorizedKeysAccount.login(server)
    key = public_key.authorized_key
    output = Ssh::Connection.open(server, **connection_options) do |ssh|
      ssh.run_command!(replace ? "keys.replace" : "keys.append", line: line_for(public_key, expires_at), blob: key.key).stdout
    end

    Result.new(status: output.include?("present") ? :already_present : :added, error_title: nil, error_details: nil)
  rescue Ssh::Connection::Error => e
    title, details = account.error_for(e)
    Result.new(status: :error, error_title: title, error_details: details)
  end

  def self.line_for(public_key, expires_at = nil)
    key = public_key.authorized_key
    options = %(expiry-time="#{expires_at.utc.strftime("%Y%m%d%H%M%S")}Z" ) if expires_at
    "#{options}#{key.type} #{key.key} #{public_key.name}"
  end

  # The command sent (config/ssh_commands.yml: keys.append / keys.replace),
  # also run locally by the tests.
  def self.command(line, blob, replace: false) = Ssh::Commands.render(replace ? "keys.replace" : "keys.append", line: line, blob: blob)
end
