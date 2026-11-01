require "net/http"

# Downloads a vulnerability feed to a temporary file, streamed (never whole
# in memory): HTTPS only, a few redirects, size capped.
module Vulnerabilities::Download
  MAX_SIZE = 1.gigabyte
  MAX_REDIRECTS = 3

  # Trusted certificates (nil: the system's); tests trust a local server.
  mattr_accessor :cert_store

  # Yields the path of the downloaded file (removed afterwards).
  def self.open(url, max_size: MAX_SIZE)
    Tempfile.create([ "elio-feed", File.extname(URI(url).path) ], binmode: true) do |file|
      fetch(URI(url), file, max_size, MAX_REDIRECTS)
      file.flush
      yield file.path
    end
  end

  def self.fetch(uri, file, max_size, redirects)
    raise Vulnerabilities::Error, "Adresse refusée (HTTPS seulement) : #{uri}" unless uri.is_a?(URI::HTTPS)

    options = { use_ssl: true, open_timeout: 15, read_timeout: 120 }
    options[:cert_store] = cert_store if cert_store
    Net::HTTP.start(uri.host, uri.port, **options) do |http|
      http.request(Net::HTTP::Get.new(uri, "User-Agent" => "Elio")) do |response|
        case response
        when Net::HTTPRedirection
          raise Vulnerabilities::Error, "Trop de redirections pour #{uri}" if redirects.zero?

          return fetch(URI.join(uri, response["location"]), file, max_size, redirects - 1)
        when Net::HTTPSuccess
          size = 0
          response.read_body do |chunk|
            size += chunk.bytesize
            raise Vulnerabilities::Error, "Fichier trop volumineux (plus de #{max_size / 1.megabyte} Mo)" if size > max_size

            file.write(chunk)
          end
        else
          raise Vulnerabilities::Error, "Téléchargement impossible (HTTP #{response.code}) : #{uri}"
        end
      end
    end
  rescue SocketError, SystemCallError, IOError, OpenSSL::SSL::SSLError, Net::OpenTimeout, Net::ReadTimeout => e
    raise Vulnerabilities::Error, "Téléchargement impossible : #{e.message.truncate(120)}"
  end
end
