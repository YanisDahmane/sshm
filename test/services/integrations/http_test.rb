require "test_helper"

class Integrations::HttpTest < ActiveSupport::TestCase
  include TcpHelpers

  # A one-shot local HTTP server answering `status` and `body`; yields its URL
  # and returns the raw request it received.
  def with_http_server(status: "200 OK", body: "ok")
    server = TCPServer.new("127.0.0.1", 0)
    request = +""
    thread = Thread.new do
      client = server.accept
      while (line = client.gets) && line != "\r\n"
        request << line
      end
      client.write("HTTP/1.1 #{status}\r\nContent-Type: text/plain\r\nContent-Length: #{body.bytesize}\r\nConnection: close\r\n\r\n#{body}")
      client.close
    end
    yield "http://127.0.0.1:#{server.addr[1]}/metrics"
    thread.join(5)
    request
  ensure
    server&.close
  end

  test "GETs the body, with basic auth and headers" do
    body = nil
    request = with_http_server(body: "monitor_status 1") do |url|
      body = Integrations::Http.get(url, service: "Uptime Kuma", basic_auth: [ "", "key" ], headers: { "X-Test" => "1" })
    end

    assert_equal "monitor_status 1", body
    assert_match %r{\AGET /metrics HTTP/1.1}, request
    assert_match "Authorization: Basic #{Base64.strict_encode64(":key")}", request
    assert_match "X-Test: 1", request
    assert_match "User-Agent: Elio", request
  end

  test "an access refused, another error" do
    error = assert_raises(Integrations::Error) { with_http_server(status: "401 Unauthorized") { |url| Integrations::Http.get(url, service: "Uptime Kuma") } }
    assert_equal "Uptime Kuma refuse l'accès (401) : vérifiez la clé API", error.message

    error = assert_raises(Integrations::Error) { with_http_server(status: "500 Internal Server Error", body: "boom") { |url| Integrations::Http.get(url, service: "OVH") } }
    assert_equal "OVH a répondu 500 : boom", error.message
  end

  test "an unreachable service or an invalid address" do
    error = assert_raises(Integrations::Error) { Integrations::Http.get("http://127.0.0.1:#{closed_port}/", service: "Uptime Kuma") }
    assert_match "Impossible de joindre Uptime Kuma", error.message

    error = assert_raises(Integrations::Error) { Integrations::Http.get("not a url", service: "Uptime Kuma") }
    assert_match "Adresse invalide", error.message
  end

  test "stops reading an answer larger than the limit (AUDIT.md S23)" do
    stub_const_limit = Integrations::Http::MAX_BODY
    Integrations::Http.send(:remove_const, :MAX_BODY)
    Integrations::Http.const_set(:MAX_BODY, 1_000)
    error = assert_raises(Integrations::Error) { with_http_server(body: "x" * 5_000) { |url| Integrations::Http.get(url, service: "Uptime Kuma") } }
    assert_match "trop volumineuse", error.message
  ensure
    Integrations::Http.send(:remove_const, :MAX_BODY)
    Integrations::Http.const_set(:MAX_BODY, stub_const_limit)
  end

  test "read-only by construction: no other method than GET" do
    assert_equal [ :get ], Integrations::Http.singleton_methods.sort
  end
end
