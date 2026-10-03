# Reads the authorized_keys file of the SSH user configured on a server and
# parses it into AuthorizedKey objects. Never raises: failures are returned
# in the Result with a French title.
class AuthorizedKeysReader
  PATH = "~/.ssh/authorized_keys".freeze

  Result = Data.define(:keys, :error_title, :error_details) do
    def success? = error_title.nil?
  end

  def self.call(server, **connection_options)
    output = SshConnection.open(server, **connection_options) { |ssh| ssh.exec("cat #{PATH}") }

    if output.success?
      Result.new(keys: AuthorizedKey.parse(output.stdout), error_title: nil, error_details: nil)
    elsif output.stderr.include?("No such file or directory")
      Result.new(keys: [], error_title: nil, error_details: nil)
    else
      Result.new(keys: [], error_title: "Impossible de lire #{PATH}", error_details: output.stderr.strip.presence || "Code de sortie #{output.exit_status}")
    end
  rescue SshConnection::Error => e
    Result.new(keys: [], error_title: e.title, error_details: e.message)
  end
end
