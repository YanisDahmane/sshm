# CISA KEV: the catalog of the vulnerabilities exploited in the wild (≈ 1.5 MB
# JSON, daily). A CVE of the fleet in it gets score 1 and the date it was
# added (and whether ransomware uses it); the others score nil.
class Vulnerabilities::Scores::Kev < Vulnerabilities::Scores::Base
  FEED = ENV.fetch("ELIO_KEV_URL", "https://www.cisa.gov/sites/default/files/feeds/known_exploited_vulnerabilities.json")
  EVERY = 20.hours

  def fetch(cves)
    return 0 if provider.state["fetched_at"] && Time.zone.parse(provider.state["fetched_at"]) > EVERY.ago && CveScore.due(provider.key, cves).empty?

    catalog = self.catalog
    CveScore.store(provider.key, cves.map { |cve| catalog[cve] ? { cve: cve, **catalog[cve].to_h } : { cve: cve, score: nil } })
    provider.update!(state: provider.state.merge("fetched_at" => Time.current.iso8601))
    cves.size
  end

  def lookup(cve) = catalog[cve]

  def catalog
    @catalog ||= Vulnerabilities::Download.open(FEED) do |path|
      Array(JSON.parse(File.read(path))["vulnerabilities"]).to_h do |entry|
        [ entry["cveID"], Score.new(score: 1, data: { "date_added" => entry["dateAdded"], "ransomware" => entry["knownRansomwareCampaignUse"] == "Known",
                                                     "name" => entry["vulnerabilityName"] }) ]
      end
    end
  rescue JSON::ParserError => e
    raise Vulnerabilities::Error, I18n.t("vulnerabilities.scores.kev.unreadable", truncate: (e.message.truncate(120)))
  end
end
