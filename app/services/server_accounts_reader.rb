# Lists the Unix accounts of a server whose SSH keys can be managed: root and
# the regular users (UID >= 1000) that have a login shell. The login user
# always comes first, then root, then the others alphabetically. Never raises.
class ServerAccountsReader
  NO_LOGIN_SHELLS = %r{/(nologin|false|sync|shutdown|halt)\z}

  Result = Data.define(:accounts, :error_title, :error_details, :reason) do
    def initialize(accounts:, error_title:, error_details:, reason: nil) = super
    def success? = error_title.nil?
  end

  def self.call(server, **connection_options)
    passwd = SshConnection.open(server, **connection_options) do |ssh|
      ssh.exec!("getent passwd 2>/dev/null || cat /etc/passwd").stdout
    end

    Result.new(accounts: accounts_from(server, passwd), error_title: nil, error_details: nil)
  rescue SshConnection::Error => e
    Result.new(accounts: [ AuthorizedKeysAccount.login(server) ], error_title: e.title, error_details: e.message, reason: e.reason)
  end

  def self.accounts_from(server, passwd)
    users = passwd.each_line.filter_map do |line|
      name, _password, uid, _gid, _gecos, _home, shell = line.strip.split(":")
      next unless name&.match?(AuthorizedKeysAccount::USERNAME_FORMAT) && uid&.match?(/\A\d+\z/)

      name if uid.to_i.zero? || (uid.to_i >= 1000 && uid.to_i != 65_534 && !shell.to_s.match?(NO_LOGIN_SHELLS))
    end

    names = [ server.username, ("root" if users.include?("root")), *users.sort ].compact.uniq
    names.map { |name| AuthorizedKeysAccount.for(server, name) }
  end
end
