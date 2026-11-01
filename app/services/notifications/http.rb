require "net/http"

# POSTs a JSON body to a webhook (Slack, Discord, generic) with short
# timeouts; any failure becomes a Notifications::DeliveryError.
module Notifications::Http
  TIMEOUT = 5 # seconds

  def self.post(url, body, service:, headers: {})
    uri = URI(url)
    response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https", open_timeout: TIMEOUT, read_timeout: TIMEOUT) do |http|
      http.post(uri.request_uri, body, { "Content-Type" => "application/json", "User-Agent" => "Elio" }.merge(headers))
    end
    raise Notifications::DeliveryError, I18n.t("notifications.http.answered", service: service, code: response.code, truncate: (response.body.to_s.truncate(200))) unless response.is_a?(Net::HTTPSuccess)

    response
  rescue SocketError, SystemCallError, IOError, Timeout::Error, OpenSSL::SSL::SSLError, Net::HTTPBadResponse => e
    raise Notifications::DeliveryError, I18n.t("notifications.http.unreachable", service: service, class: e.class, message: e.message)
  end
end
