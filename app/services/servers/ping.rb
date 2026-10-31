require "socket"

# Checks whether a server accepts TCP connections on its SSH port and
# records the result on the server (`reachable`, `last_checked_at`).
#
# A TCP connect is used rather than ICMP: it needs no root privileges and
# tells us whether SSH is actually reachable, even when ICMP is filtered.
class Servers::Ping
  DEFAULT_TIMEOUT = 3 # seconds
  PARALLEL_LIMIT = 32 # pings at once (network only, no database)

  NETWORK_ERRORS = [ SocketError, SystemCallError, IOError, Timeout::Error ].freeze

  def self.reachable?(host, port, timeout: DEFAULT_TIMEOUT)
    # Ruby 3.4's Happy Eyeballs `Socket.tcp` can yield a socket whose
    # connection was in fact refused (seen on macOS): asking for the peer
    # address (getpeername) raises in that case, so only a real connection
    # counts as reachable.
    Socket.tcp(host, port, connect_timeout: timeout, resolv_timeout: timeout) do |socket|
      socket.remote_address
      true
    end
  rescue *NETWORK_ERRORS
    false
  end

  # Pings one server and persists the result. Returns true when reachable.
  def self.check!(server, timeout: DEFAULT_TIMEOUT)
    record(server, reachable?(server.host, server.port, timeout: timeout))
  end

  # Pings servers concurrently (up to PARALLEL_LIMIT at a time) so the total
  # time stays close to the slowest check. Database writes stay on the
  # calling thread.
  def self.check_all!(servers, timeout: DEFAULT_TIMEOUT)
    servers = servers.to_a
    results = BoundedParallel.map(servers, limit: PARALLEL_LIMIT) { |server| reachable?(server.host, server.port, timeout: timeout) }

    servers.zip(results).to_h { |server, reachable| [ server, record(server, reachable) ] }
  end

  def self.record(server, reachable)
    server.record_reachability!(reachable)
    reachable
  end
  private_class_method :record
end
