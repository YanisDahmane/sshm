require "test_helper"

class Integrations::Ovh::ClientTest < ActiveSupport::TestCase
  include StubHelpers
  include OvhHelpers

  def client = Integrations::Ovh::Client.new(endpoint: "ovh-eu", application_key: "app-key", application_secret: "app-secret", consumer_key: "consumer-key")

  test "signs each GET with the API clock" do
    fake_ovh({ "/ip" => [ "203.0.113.10/32" ] })
    assert_equal [ "203.0.113.10/32" ], client.get("/ip")

    url, headers = @ovh_requests.last
    assert_equal "#{OVH_BASE}/ip", url
    assert_equal [ "app-key", "consumer-key" ], headers.values_at("X-Ovh-Application", "X-Ovh-Consumer")
    expected = "$1$" + Digest::SHA1.hexdigest("app-secret+consumer-key+GET+#{OVH_BASE}/ip++#{headers["X-Ovh-Timestamp"]}")
    assert_equal expected, headers["X-Ovh-Signature"]
    assert_in_delta Time.now.to_i, headers["X-Ovh-Timestamp"].to_i, 2
    assert_equal "#{OVH_BASE}/auth/time", @ovh_requests.first.first
  end

  test "signature: the documented formula" do
    assert_equal "$1$#{Digest::SHA1.hexdigest("AS+CK+GET+https://eu.api.ovh.com/1.0/me++1366560945")}",
                 Integrations::Ovh::Client.signature("AS", "CK", "GET", "https://eu.api.ovh.com/1.0/me", "", "1366560945")
  end

  test "read-only by construction and readable errors" do
    assert_equal [ :get ], Integrations::Ovh::Client.public_instance_methods(false)
    fake_ovh({})
    error = assert_raises(Integrations::Error) { client.get("/vps") }
    assert_match "404", error.message
    assert_raises(Integrations::Error) { Integrations::Ovh::Client.new(endpoint: "nope", application_key: "", application_secret: "", consumer_key: "") }
    assert_equal "203.0.113.10%2F32", Integrations::Ovh::Client.segment("203.0.113.10/32")
  end
end
