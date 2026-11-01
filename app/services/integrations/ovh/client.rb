require "digest"
require "json"

# Signed client of the OVHcloud API, read-only by construction: GET is its
# only request. Signature: "$1$" + SHA1(secret+consumer+method+url+body+time),
# the time aligned on the API's clock (/auth/time).
class Integrations::Ovh::Client
  ENDPOINTS = { "ovh-eu" => "https://eu.api.ovh.com/1.0", "ovh-ca" => "https://ca.api.ovh.com/1.0", "ovh-us" => "https://api.us.ovhcloud.com/1.0" }.freeze
  TOKEN_PAGES = { "ovh-eu" => "https://eu.api.ovh.com/createToken/", "ovh-ca" => "https://ca.api.ovh.com/createToken/",
                  "ovh-us" => "https://api.us.ovhcloud.com/createToken/" }.freeze

  def initialize(endpoint:, application_key:, application_secret:, consumer_key:)
    @base = ENDPOINTS.fetch(endpoint) { raise Integrations::Error, I18n.t("integrations.ovh.client.unknown_endpoint", endpoint: endpoint) }
    @application_key = application_key.to_s
    @application_secret = application_secret.to_s
    @consumer_key = consumer_key.to_s
  end

  # GET a path ("/ip", "/domain/zone/example.com/record?fieldType=A") → parsed JSON.
  def get(path)
    url = "#{@base}#{path}"
    timestamp = (Time.now.to_i + time_delta).to_s
    headers = { "X-Ovh-Application" => @application_key, "X-Ovh-Consumer" => @consumer_key, "X-Ovh-Timestamp" => timestamp,
                "X-Ovh-Signature" => self.class.signature(@application_secret, @consumer_key, "GET", url, "", timestamp),
                "Accept" => "application/json" }
    JSON.parse(Integrations::Http.get(url, service: "OVHcloud", headers: headers))
  rescue JSON::ParserError
    raise Integrations::Error, I18n.t("integrations.ovh.client.unreadable", path: path)
  end

  def self.signature(secret, consumer_key, method, url, body, timestamp)
    "$1$#{Digest::SHA1.hexdigest([ secret, consumer_key, method, url, body, timestamp ].join("+"))}"
  end

  # "/ip/1.2.3.4/32" → "/ip/1.2.3.4%2F32"
  def self.segment(value) = ERB::Util.url_encode(value.to_s)

  private

  # Difference between the API clock and ours (requests too far off are refused).
  def time_delta
    @time_delta ||= Integer(Integrations::Http.get("#{@base}/auth/time", service: "OVHcloud").strip) - Time.now.to_i
  rescue ArgumentError
    raise Integrations::Error, I18n.t("integrations.ovh.client.unreadable_time")
  end
end
