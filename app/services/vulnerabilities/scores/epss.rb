require "zlib"
require "csv"

# EPSS (FIRST): probability that a CVE is exploited in the next 30 days, and
# its percentile. One daily file of every CVE (≈ 3 MB): only the fleet's are
# kept; a CVE absent from it has no EPSS. `test` asks the EPSS API.
class Vulnerabilities::Scores::Epss < Vulnerabilities::Scores::Base
  FEED = ENV.fetch("ELIO_EPSS_URL", "https://epss.empiricalsecurity.com/epss_scores-current.csv.gz")
  API = "https://api.first.org/data/v1/epss?cve={cve}"
  EVERY = 20.hours

  def fetch(cves)
    return 0 if provider.state["fetched_at"] && Time.zone.parse(provider.state["fetched_at"]) > EVERY.ago && CveScore.due(provider.key, cves).empty?

    wanted = cves.to_set
    rows = {}
    Vulnerabilities::Download.open(FEED) do |path|
      Zlib::GzipReader.open(path) do |gzip|
        gzip.each_line do |line|
          cve, epss, percentile = line.strip.split(",")
          next unless wanted.include?(cve)

          rows[cve] = { cve: cve, score: epss.to_f, data: { "percentile" => percentile.to_f } }
        end
      end
    end
    CveScore.store(provider.key, cves.map { |cve| rows[cve] || { cve: cve, score: nil } })
    provider.update!(state: provider.state.merge("fetched_at" => Time.current.iso8601))
    cves.size
  rescue Zlib::Error => e
    raise Vulnerabilities::Error, "Fichier EPSS illisible : #{e.message}"
  end

  def lookup(cve)
    body = get(url_for(API, cve)) or return nil
    entry = Array(JSON.parse(body)["data"]).first or return nil
    Score.new(score: entry["epss"].to_f, data: { "percentile" => entry["percentile"].to_f })
  end
end
