require "socket"

# Checks whether a server accepts TCP connections on its SSH port and
# records the result on the server (`reachable`, `last_checked_at`).
#
# A TCP connect is used rather than ICMP: it needs no root privileges and
# tells us whether SSH is actually reachable, even when ICMP is filtered.
class ServerPing
  DEFAULT_TIMEOUT = 3 # seconds

  NETWORK_ERRORS = [ SocketError, SystemCallError, IOError, Timeout::Error ].freeze

  def self.reachable?(host, port, timeout: DEFAULT_TIMEOUT)
    Socket.tcp(host, port, connect_timeout: timeout, resolv_timeout: timeout) { true }
  rescue *NETWORK_ERRORS
    false
  end

  # Pings one server and persists the result. Returns true when reachable.
  def self.check!(server, timeout: DEFAULT_TIMEOUT)
    record(server, reachable?(server.host, server.port, timeout: timeout))
  end

  # Pings servers concurrently so the total time is bounded by the slowest
  # check, not their sum. Database writes stay on the calling thread.
  def self.check_all!(servers, timeout: DEFAULT_TIMEOUT)
    servers = servers.to_a
    results = servers.map { |server| Thread.new { reachable?(server.host, server.port, timeout: timeout) } }.map(&:value)

    servers.zip(results).to_h { |server, reachable| [ server, record(server, reachable) ] }
  end

  def self.record(server, reachable)
    server.record_reachability!(reachable)
    reachable
  end
  private_class_method :record
end
