require "test_helper"
require "openssl"

class Vulnerabilities::DownloadTest < ActiveSupport::TestCase
  # A real HTTPS server on 127.0.0.1 with a self-signed certificate that the download trusts.
  def with_https_server(responses)
    key = OpenSSL::PKey::EC.generate("prime256v1")
    cert = OpenSSL::X509::Certificate.new.tap do |certificate|
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
    context = OpenSSL::SSL::SSLContext.new.tap { |ssl| ssl.cert = cert; ssl.key = key }
    tcp = TCPServer.new("127.0.0.1", 0)
    server = OpenSSL::SSL::SSLServer.new(tcp, context)
    thread = Thread.new do
      loop do
        socket = server.accept
        path = socket.gets.to_s.split[1]
        nil while (line = socket.gets) && line != "\r\n"
        socket.write(responses.fetch(path, "HTTP/1.1 404 Not Found\r\nContent-Length: 0\r\nConnection: close\r\n\r\n"))
        socket.close
      rescue OpenSSL::SSL::SSLError, IOError, Errno::ECONNRESET
        next
      end
    end
    Vulnerabilities::Download.cert_store = OpenSSL::X509::Store.new.tap { |store| store.add_cert(cert) }
    yield "https://127.0.0.1:#{tcp.addr[1]}"
  ensure
    Vulnerabilities::Download.cert_store = nil
    thread&.kill
    tcp&.close
  end

  def ok(body) = "HTTP/1.1 200 OK\r\nContent-Length: #{body.bytesize}\r\nConnection: close\r\n\r\n#{body}"

  test "downloads to a temporary file, following a redirect, removed afterwards" do
    with_https_server("/feed" => "HTTP/1.1 302 Found\r\nLocation: /data.json\r\nContent-Length: 0\r\nConnection: close\r\n\r\n", "/data.json" => ok(%({"a": 1}))) do |base|
      kept = nil
      Vulnerabilities::Download.open("#{base}/feed") do |path|
        kept = path
        assert_equal %({"a": 1}), File.read(path)
      end
      assert_not File.exist?(kept)
    end
  end

  test "an HTTP error, a file too big, a plain HTTP address" do
    with_https_server("/big" => ok("x" * 2000)) do |base|
      error = assert_raises(Vulnerabilities::Error) { Vulnerabilities::Download.open("#{base}/missing") { } }
      assert_match "HTTP 404", error.message
      assert_raises(Vulnerabilities::Error) { Vulnerabilities::Download.open("#{base}/big", max_size: 1000) { } }
    end
    assert_match "HTTPS seulement", assert_raises(Vulnerabilities::Error) { Vulnerabilities::Download.open("http://example.com/feed") { } }.message
  end
end
