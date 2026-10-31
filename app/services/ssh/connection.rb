require "net/ssh"

# Opens an SSH session to a Server to run commands (no interactive shell).
#
#   Ssh::Connection.open(server) do |ssh|
#     ssh.exec!("cat /root/.ssh/authorized_keys").stdout
#   end
#
# Authentication only uses the app's SSH keys (SshKey.app_keys: the active key,
# plus the pending one during a rotation), never ~/.ssh nor the ssh-agent.
# Host keys are trusted on first use and pinned in KNOWN_HOSTS_FILE; a changed
# key aborts the connection.
class Ssh::Connection
  # Each error has a short French `title` to show in the UI next to its message.
  # `reason` lets the UI guide the user: :key_refused (install the app key on
  # the server) or :missing_key (generate it in the settings).
  class Error < StandardError
    def title = "Erreur SSH"
    def reason = nil
  end

  class ConnectionError < Error
    def title = "Connexion impossible"
  end

  class AuthenticationError < Error
    def title = "Clé SSH refusée par le serveur"
    def reason = :key_refused
  end

  # Carries the fingerprint the server presents and the pinned ones, so an
  # admin can decide to trust the new one (ServerHostKeysController).
  class HostKeyMismatchError < Error
    attr_reader :new_fingerprint, :known_fingerprints

    def initialize(message = nil, new_fingerprint: nil, known_fingerprints: [])
      @new_fingerprint = new_fingerprint
      @known_fingerprints = known_fingerprints
      super(message)
    end

    def title = "L'empreinte du serveur a changé"
    def reason = :host_key_changed
  end

  class MissingKeyError < Error
    def title = "Aucune clé SSH configurée"
    def reason = :missing_key
  end

  # The command ran longer than its time limit: its channel and the session
  # are closed, so the connection cannot be used anymore.
  class CommandTimeoutError < Error
    def title = "Délai dépassé"
  end

  class CommandError < Error
    attr_reader :result

    def title = "La commande a échoué"

    def initialize(command, result)
      @result = result
      super("`#{command}` exited with status #{result.exit_status}: #{result.stderr.strip.presence || "no output"}")
    end
  end

  Result = Data.define(:stdout, :stderr, :exit_status) do
    def success? = exit_status.zero?
  end

  KNOWN_HOSTS_FILE = Rails.root.join("storage", "ssh", "known_hosts")
  DEFAULT_TIMEOUT = 10 # seconds, to connect
  DEFAULT_COMMAND_TIMEOUT = 60 # seconds, per command

  attr_reader :server

  def self.open(server, **options, &block)
    new(server, **options).open(&block)
  end

  # `transport` is the Net::SSH-compatible entry point, swappable in tests.
  # `key`: one SshKey or a list, tried in order (the app keys by default).
  def initialize(server, key: SshKey.app_keys, timeout: DEFAULT_TIMEOUT, command_timeout: DEFAULT_COMMAND_TIMEOUT,
                 known_hosts_file: Ssh::KnownHosts.file, transport: Net::SSH)
    @server = server
    @keys = Array(key).compact
    @timeout = timeout
    @command_timeout = command_timeout
    @known_hosts_file = Pathname(known_hosts_file)
    @transport = transport
  end

  # Yields the connection and closes the session afterwards. Returns the block's value.
  def open
    raise MissingKeyError, "Aucune clé SSH configurée : générez-en une dans les paramètres." if @keys.empty?

    FileUtils.mkdir_p(@known_hosts_file.dirname)

    @transport.start(server.host, server.username, **ssh_options) do |session|
      @session = session
      yield self
    ensure
      @session = nil
      @privilege = nil
      @timed_out = false
    end
  rescue Net::SSH::AuthenticationFailed => e
    raise AuthenticationError, "Authentification refusée pour #{server.username}@#{server.host} (#{e.message})"
  rescue Net::SSH::HostKeyMismatch => e
    raise HostKeyMismatchError.new("La clé d'hôte de #{server.host} a changé (#{e.fingerprint}). Connexion refusée.",
                                   new_fingerprint: e.fingerprint,
                                   known_fingerprints: Ssh::KnownHosts.fingerprints(server.host, server.port, file: @known_hosts_file))
  rescue Net::SSH::ConnectionTimeout, Net::SSH::Disconnect, Net::SSH::Exception, SocketError, SystemCallError, IOError, Timeout::Error => e
    raise ConnectionError, "Impossible de se connecter à #{server.host}:#{server.port} (#{e.class}: #{e.message})"
  end

  # Runs a command and returns its Result, whatever the exit status. Raises
  # CommandTimeoutError (and shuts the session down) after `timeout` seconds.
  def exec(command, timeout: @command_timeout)
    raise CommandTimeoutError, "La session a été fermée après un délai dépassé." if @timed_out
    raise Error, "No open session, call #exec inside Ssh::Connection.open" unless @session

    stdout = +""
    stderr = +""
    exit_status = -1
    channel = @session.open_channel do |opened|
      opened.exec(command) do |_channel, started|
        next stderr << "the server refused to run the command" unless started

        opened.on_data { |_, data| stdout << data }
        opened.on_extended_data { |_, _, data| stderr << data }
        opened.on_request("exit-status") { |_, data| exit_status = data.read_long }
      end
    end

    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + timeout
    @session.loop(0.1) { channel.active? && Process.clock_gettime(Process::CLOCK_MONOTONIC) < deadline }
    raise_timeout(command, timeout) if channel.active?

    Result.new(stdout: stdout, stderr: stderr, exit_status: exit_status)
  end

  # Runs a command and raises CommandError unless it succeeds.
  def exec!(command, **options)
    exec(command, **options).tap { |result| raise CommandError.new(command, result) unless result.success? }
  end

  # How commands needing root can run on this server, checked once per session:
  # :root (logged in as root), :sudo (passwordless `sudo -n`) or :none.
  def privilege
    @privilege ||= if server.username == "root" then :root
    elsif exec("sudo -n true", timeout: 10).success? then :sudo
    else :none
    end
  end

  def privileged? = privilege != :none

  # `command` prefixed with `sudo -n` when root is reached through sudo; as is
  # otherwise (already root, or no root access: it runs with the user's rights).
  def privileged(command) = privilege == :sudo ? "sudo -n #{command}" : command

  private

  def raise_timeout(command, timeout)
    @session.shutdown!
    @timed_out = true
    raise CommandTimeoutError, "La commande n'a pas répondu en #{timeout} s sur #{server.host} : #{command.truncate(80)}"
  end

  def ssh_options
    {
      port: server.port,
      timeout: @timeout,
      non_interactive: true,          # never prompt on the app's stdin
      config: false,                  # ignore the app user's ~/.ssh/config
      verify_host_key: :accept_new,   # trust on first use, reject changed keys
      user_known_hosts_file: @known_hosts_file.to_s,
      global_known_hosts_file: [],
      keepalive: true,
      keepalive_interval: 15,
      logger: Rails.logger,
      verbose: :fatal,
      auth_methods: %w[publickey],
      key_data: @keys.map(&:private_key),
      keys: [],
      keys_only: true,                # only the app key, never ~/.ssh/id_*
      use_agent: false
    }
  end
end
