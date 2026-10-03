require "socket"

# Local TCP endpoints so reachability tests never touch the real network.
module TcpHelpers
  # Yields the port of a listening socket on 127.0.0.1.
  def with_open_port
    server = TCPServer.new("127.0.0.1", 0)
    yield server.addr[1]
  ensure
    server&.close
  end

  # Returns a port on 127.0.0.1 with nothing listening (connection refused).
  def closed_port
    server = TCPServer.new("127.0.0.1", 0)
    server.addr[1].tap { server.close }
  end
end
