require "net/http"
require "base64"

# Reads the digest of an image tag from its registry (Docker Registry HTTP
# API v2): HEAD /v2/<repository>/manifests/<tag>, after the token dance when
# the registry asks for one (WWW-Authenticate: Bearer realm=…, anonymous or
# with the credentials of the settings), or Basic auth. HTTPS only.
class ImageRegistry::Client
  ACCEPT = %w[application/vnd.oci.image.index.v1+json application/vnd.docker.distribution.manifest.list.v2+json
              application/vnd.docker.distribution.manifest.v2+json application/vnd.oci.image.manifest.v1+json].join(", ")
  TIMEOUT = 10

  class RateLimited < ImageRegistry::Error; end

  # Trusted certificates (nil: the system's); tests trust a local server.
  cattr_accessor :cert_store

  # `credentials`: { "ghcr.io" => ["user", "token"] }.
  def initialize(credentials: {})
    @credentials = credentials
    @tokens = {}
  end

  def digest(reference)
    uri = URI("https://#{reference.host}/v2/#{reference.repository}/manifests/#{reference.tag}")
    response = head(uri, authorization(reference))
    if response.is_a?(Net::HTTPUnauthorized) && (challenge = response["www-authenticate"])
      response = head(uri, authenticate(reference, challenge))
    end

    case response
    when Net::HTTPSuccess then response["docker-content-digest"].presence || raise(ImageRegistry::Error, "Le registre ne donne pas d'empreinte")
    when Net::HTTPNotFound then raise ImageRegistry::Error, "Tag introuvable sur le registre"
    when Net::HTTPUnauthorized, Net::HTTPForbidden then raise ImageRegistry::Error, "Accès refusé par le registre (image privée ? identifiants dans Paramètres → Docker)"
    when Net::HTTPTooManyRequests then raise RateLimited, "Limite de requêtes du registre atteinte"
    else raise ImageRegistry::Error, "Réponse inattendue du registre (HTTP #{response.code})"
    end
  end

  private

  def authorization(reference) = @tokens[[ reference.registry, reference.repository ]]

  # Bearer: a pull token for the repository; Basic: the credentials as is.
  def authenticate(reference, challenge)
    user, password = @credentials[reference.registry]
    scheme, params = challenge.split(" ", 2)
    if scheme.casecmp?("basic")
      raise ImageRegistry::Error, "Le registre demande des identifiants (Paramètres → Docker)" unless user

      return @tokens[[ reference.registry, reference.repository ]] = "Basic #{Base64.strict_encode64("#{user}:#{password}")}"
    end

    fields = params.to_s.scan(/(\w+)="([^"]*)"/).to_h
    realm = URI(fields.fetch("realm") { raise ImageRegistry::Error, "Authentification du registre illisible" })
    raise ImageRegistry::Error, "Adresse d'authentification refusée (HTTPS seulement)" unless realm.is_a?(URI::HTTPS)

    realm.query = URI.encode_www_form({ service: fields["service"], scope: fields["scope"] || "repository:#{reference.repository}:pull" }.compact)
    request = Net::HTTP::Get.new(realm, "User-Agent" => "Elio")
    request.basic_auth(user, password) if user
    response = http(realm) { |connection| connection.request(request) }
    raise ImageRegistry::Error, "Jeton du registre refusé (HTTP #{response.code})" unless response.is_a?(Net::HTTPSuccess)

    token = JSON.parse(response.body).then { |body| body["token"] || body["access_token"] }
    raise ImageRegistry::Error, "Jeton du registre illisible" if token.blank?

    @tokens[[ reference.registry, reference.repository ]] = "Bearer #{token}"
  rescue JSON::ParserError
    raise ImageRegistry::Error, "Jeton du registre illisible"
  end

  def head(uri, authorization)
    request = Net::HTTP::Head.new(uri, "Accept" => ACCEPT, "User-Agent" => "Elio")
    request["Authorization"] = authorization if authorization
    http(uri) { |connection| connection.request(request) }
  end

  def http(uri, &block)
    options = { use_ssl: true, open_timeout: TIMEOUT, read_timeout: TIMEOUT }
    options[:cert_store] = cert_store if cert_store
    Net::HTTP.start(uri.host, uri.port, **options, &block)
  rescue SocketError, SystemCallError, IOError, OpenSSL::SSL::SSLError, Net::OpenTimeout, Net::ReadTimeout => e
    raise ImageRegistry::Error, "Registre injoignable : #{e.message.truncate(100)}"
  end
end
