require "shellwords"

# The Unix account whose authorized_keys file is managed on a server: the SSH
# user the app logs in as, root, or any other user. Other accounts are reached
# as root, with `sudo -n` (passwordless sudo required) unless the app already
# logs in as root.
class AuthorizedKeysAccount
  # Portable Unix user names; also guarantees `~name` is safe to put in a script.
  USERNAME_FORMAT = /\A[a-z_][a-z0-9_.-]{0,31}\z/i

  attr_reader :server, :unix_user

  def self.for(server, unix_user)
    raise ArgumentError, "Invalid Unix user name: #{unix_user.inspect}" unless unix_user.to_s.match?(USERNAME_FORMAT)

    new(server, unix_user.to_s)
  end

  def self.login(server) = new(server, server.username)

  def initialize(server, unix_user)
    @server = server
    @unix_user = unix_user
  end

  def name = unix_user

  def login? = unix_user == server.username

  def root? = unix_user == "root"

  # Commands for another account than the login one run as root.
  def sudo? = !login? && server.username != "root"

  # Shell expression of the account's home directory, assigned to `home=` at
  # the top of scripts (`~user` does not expand inside double quotes).
  def home = login? ? "$HOME" : "~#{unix_user}"

  # Files written as root in another user's home must be given back to that
  # user, or sshd refuses them.
  def owner = (login? || root?) ? nil : unix_user

  def path = "~#{unix_user}/.ssh/authorized_keys"

  # Command running `script` with sh, as root through sudo when needed.
  def command(script)
    "#{"sudo -n " if sudo?}sh -c #{Shellwords.escape(script)}"
  end

  # [title, details] to display for an SshConnection error.
  def error_for(error)
    stderr = error.is_a?(SshConnection::CommandError) ? error.result.stderr.strip : ""

    if stderr.include?("unknown user")
      [ "Utilisateur inconnu", "L'utilisateur #{unix_user} n'existe pas sur #{server.name}." ]
    elsif sudo? && stderr.include?("sudo")
      [ "Accès root impossible", "#{stderr} — l'utilisateur #{server.username} doit pouvoir lancer sudo sans mot de passe." ]
    else
      [ error.title, error.message ]
    end
  end

  def ==(other) = other.is_a?(self.class) && other.server == server && other.unix_user == unix_user
  alias eql? ==

  def hash = [ self.class, server, unix_user ].hash
end
