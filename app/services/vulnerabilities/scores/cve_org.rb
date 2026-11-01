# CVE.org (CVE Services API, cveawg.mitre.org/api/cve/<CVE>): the CVSS of the
# CNA that published the CVE, else the one added by CISA (ADP "Vulnrichment").
# The most recent CVSS version first.
class Vulnerabilities::Scores::CveOrg < Vulnerabilities::Scores::Base
  URL = "https://cveawg.mitre.org/api/cve/{cve}"
  METRICS = { "cvssV4_0" => "4.0", "cvssV3_1" => "3.1", "cvssV3_0" => "3.0", "cvssV2_0" => "2.0" }.freeze

  def fetch(cves) = fetch_each(cves)

  def lookup(cve)
    body = get(url_for(URL, cve)) or return nil
    record = JSON.parse(body)
    cna = record.dig("containers", "cna") || {}
    cisa = Array(record.dig("containers", "adp")).find { |adp| adp.dig("providerMetadata", "shortName") == "CISA-ADP" } || {}
    [ [ cna, "CNA" ], [ cisa, "CISA" ] ].each do |container, from|
      METRICS.each do |key, version|
        metric = Array(container["metrics"]).filter_map { |entry| entry[key] }.first
        next unless metric && (score = cvss(metric["baseScore"]))

        return Score.new(score: score, version: version, vector: metric["vectorString"], severity: metric["baseSeverity"]&.downcase, data: { "from" => from })
      end
    end
    nil
  rescue JSON::ParserError
    raise Integrations::Error, "Réponse de CVE.org illisible pour #{cve}"
  end
end
