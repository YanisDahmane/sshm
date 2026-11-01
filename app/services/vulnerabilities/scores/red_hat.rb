# Red Hat Security Data API: /hydra/rest/securitydata/cve/<CVE>.json →
# cvss3.cvss3_base_score and its vector, threat_severity (404: unknown to Red Hat).
class Vulnerabilities::Scores::RedHat < Vulnerabilities::Scores::Base
  URL = "https://access.redhat.com/hydra/rest/securitydata/cve/{cve}.json"

  def fetch(cves) = fetch_each(cves)

  def lookup(cve)
    body = get(url_for(URL, cve)) or return nil
    report = JSON.parse(body)
    report = JSON.parse(report) if report.is_a?(String) # some recent CVEs come JSON-encoded twice
    return nil unless report.is_a?(Hash)

    if (score = cvss(report.dig("cvss3", "cvss3_base_score")))
      Score.new(score: score, version: "3", vector: report.dig("cvss3", "cvss3_scoring_vector"), severity: report["threat_severity"])
    elsif (score = cvss(report.dig("cvss", "cvss_base_score")))
      Score.new(score: score, version: "2", vector: report.dig("cvss", "cvss_scoring_vector"), severity: report["threat_severity"])
    end
  rescue JSON::ParserError
    raise Integrations::Error, "Réponse de Red Hat illisible pour #{cve}"
  end
end
