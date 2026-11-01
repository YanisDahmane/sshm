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
    response = Net::HTTP.start(uri.host, uri.port, **options) do |http|
      request = Net::HTTP::Get.new(uri.request_uri, { "User-Agent" => "Elio", "Accept" => "*/*" }.merge(headers))
      request.basic_auth(*basic_auth) if basic_auth
      http.request(request)
    end
    case response
    when Net::HTTPUnauthorized, Net::HTTPForbidden then raise Integrations::Error, "#{service} refuse l'accès (#{response.code}) : vérifiez la clé API"
    when Net::HTTPSuccess then nil
    else raise Integrations::Error, "#{service} a répondu #{response.code} : #{response.body.to_s.truncate(200)}"
    end
    raise Integrations::Error, "Réponse de #{service} trop volumineuse" if response.body.to_s.bytesize > MAX_BODY

    response.body.to_s
  rescue SocketError, SystemCallError, IOError, Timeout::Error, OpenSSL::SSL::SSLError, Net::HTTPBadResponse, Zlib::Error => e
    raise Integrations::Error, "Impossible de joindre #{service} (#{e.class}: #{e.message})"
  end

  def self.parse(url)
    uri = URI(url.to_s)
    raise URI::InvalidURIError unless uri.is_a?(URI::HTTP) && uri.host.present?

    uri
  rescue URI::InvalidURIError
    raise Integrations::Error, "Adresse invalide : #{url}"
  end
  private_class_method :parse
end
