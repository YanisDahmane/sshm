require "openssl"

# A real HTTPS server on 127.0.0.1 with a self-signed certificate, trusted by
# the given clients (their `cert_store`). The handler gets (method, path,
# headers) and returns the raw HTTP response; requests are recorded.
module HttpsServerHelpers
  def with_https_server(*trusting, handler:)
    key = OpenSSL::PKey::EC.generate("prime256v1")
    cert = self_signed_certificate(key)
    context = OpenSSL::SSL::SSLContext.new.tap { |ssl| ssl.cert = cert; ssl.key = key }
    tcp = TCPServer.new("127.0.0.1", 0)
    server = OpenSSL::SSL::SSLServer.new(tcp, context)
    requests = Queue.new
    thread = Thread.new do
      loop do
        socket = server.accept
        method, path = socket.gets.to_s.split
        headers = {}
        while (line = socket.gets) && line != "\r\n"
          name, value = line.split(":", 2)
          headers[name.downcase] = value.strip
        end
        requests << [ method, path, headers ]
        socket.write(handler.call(method, path, headers))
        socket.close
      rescue OpenSSL::SSL::SSLError, IOError, Errno::ECONNRESET
        next
      end
    end
    store = OpenSSL::X509::Store.new.tap { |certificates| certificates.add_cert(cert) }
    trusting.each { |client| client.cert_store = store }
    yield "127.0.0.1:#{tcp.addr[1]}", requests
  ensure
    trusting.each { |client| client.cert_store = nil }
    thread&.kill
    tcp&.close
  end

  def http_response(status, body = "", headers = {})
    head = headers.merge("Content-Length" => body.bytesize, "Connection" => "close").map { |name, value| "#{name}: #{value}\r\n" }.join
    "HTTP/1.1 #{status}\r\n#{head}\r\n#{body}"
  end

  private

  def self_signed_certificate(key)
    OpenSSL::X509::Certificate.new.tap do |certificate|
      certificate.version = 2
      certificate.serial = 1
      certificate.subject = certificate.issuer = OpenSSL::X509::Name.parse("/CN=127.0.0.1")
      certificate.public_key = key
      certificate.not_before = 1.hour.ago
      certificate.not_after = 1.hour.from_now
      extensions = OpenSSL::X509::ExtensionFactory.new(certificate, certificate)
      certificate.add_extension(extensions.create_extension("subjectAltName", "IP:127.0.0.1"))
      certificate.sign(key, OpenSSL::Digest.new("SHA256"))
    end
  end
end
