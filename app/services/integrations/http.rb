require "net/http"

# Read-only HTTP client of the extensions: only GET exists here, so an
# extension cannot change anything on the external service. Short timeouts;
# any failure becomes an Integrations::Error.
module Integrations::Http
  TIMEOUT = 10 # seconds
  MAX_BODY = 20.megabytes

  def self.get(url, service:, headers: {}, basic_auth: nil, verify_ssl: true)
    uri = parse(url)

    options = { use_ssl: uri.scheme == "https", open_timeout: TIMEOUT, read_timeout: TIMEOUT }
    options[:verify_mode] = OpenSSL::SSL::VERIFY_NONE if uri.scheme == "https" && !verify_ssl
    body = +""
    response = Net::HTTP.start(uri.host, uri.port, **options) do |http|
      request = Net::HTTP::Get.new(uri.request_uri, { "User-Agent" => "Elio", "Accept" => "*/*" }.merge(headers))
      request.basic_auth(*basic_auth) if basic_auth
      # Read in chunks and stop past MAX_BODY: a huge answer never fills the memory.
      http.request(request) do |answer|
        answer.read_body do |chunk|
          body << chunk
          raise Integrations::Error, I18n.t("integrations.http.too_large", service: service, megabyte: (MAX_BODY / 1.megabyte)) if body.bytesize > MAX_BODY
        end
      end
    end
    case response
    when Net::HTTPUnauthorized, Net::HTTPForbidden then raise Integrations::Error, I18n.t("integrations.http.forbidden", service: service, code: response.code)
    when Net::HTTPSuccess then body
    else raise Integrations::Error, I18n.t("integrations.http.answered", service: service, code: response.code, truncate: (body.truncate(200)))
    end
  rescue SocketError, SystemCallError, IOError, Timeout::Error, OpenSSL::SSL::SSLError, Net::HTTPBadResponse, Zlib::Error => e
    raise Integrations::Error, I18n.t("integrations.http.unreachable", service: service, class: e.class, message: e.message)
  end

  def self.parse(url)
    uri = URI(url.to_s)
    raise URI::InvalidURIError unless uri.is_a?(URI::HTTP) && uri.host.present?

    uri
  rescue URI::InvalidURIError
    raise Integrations::Error, I18n.t("integrations.http.invalid_url", url: url)
  end
  private_class_method :parse
end
