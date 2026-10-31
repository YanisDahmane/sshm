require "shellwords"

# The Unix account whose authorized_keys file Elio manages on a server: always
# the SSH user Elio logs in as (`server.username`).
class AuthorizedKeysAccount
  attr_reader :server, :unix_user

  def self.login(server) = new(server)

  def initialize(server)
    @server = server
    @unix_user = server.username
  end

  def name = unix_user

  # Shell expression of the home directory, assigned to `home=` at the top of
  # scripts.
  def home = "$HOME"

  def path = "~#{unix_user}/.ssh/authorized_keys"

  # Command running `script` with sh.
  def command(script) = "sh -c #{Shellwords.escape(script)}"

  # [title, details] to display for an Ssh::Connection error.
  def error_for(error) = [ error.title, error.message ]

  def ==(other) = other.is_a?(self.class) && other.server == server && other.unix_user == unix_user
  alias eql? ==

  def hash = [ self.class, server, unix_user ].hash
end
