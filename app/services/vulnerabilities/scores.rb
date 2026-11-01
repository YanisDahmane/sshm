# Severity scores of the CVEs of the fleet, from the providers of
# Settings → Vulnérabilités (ScoreProvider), stored per provider (CveScore)
# then averaged (CveRating). Read-only requests, at each provider's pace.
module Vulnerabilities::Scores
  FETCHERS = { "nvd" => "Vulnerabilities::Scores::Nvd", "redhat" => "Vulnerabilities::Scores::RedHat", "cveorg" => "Vulnerabilities::Scores::CveOrg",
               "epss" => "Vulnerabilities::Scores::Epss", "kev" => "Vulnerabilities::Scores::Kev", "custom" => "Vulnerabilities::Scores::Custom" }.freeze

  def self.fetcher(provider) = FETCHERS.fetch(provider.kind).constantize.new(provider)

  # CVE ids of the fleet (Trivy may also report GHSA-… ids: no CVSS providers for those).
  def self.fleet_cves = ServerVulnerability.where("cve LIKE 'CVE-%'").distinct.pluck(:cve).sort

  # Runs every enabled provider, then recomputes the ratings. A provider that
  # fails keeps its error (shown in the settings) and does not stop the others.
  def self.update_all(cves: fleet_cves)
    # Each provider at its own pace, side by side.
    providers = ScoreProvider.all_providers.select(&:enabled?)
    results = BoundedParallel.map(providers, limit: providers.size.clamp(1, 6)) do |provider|
      count = fetcher(provider).fetch(cves)
      provider.update!(last_run_at: Time.current, last_error: nil)
      CveRating.refresh!(cves) # its scores count at once, without waiting for the slower providers
      "#{provider.name} : #{count}"
    rescue Vulnerabilities::Error, Integrations::Error => e
      provider.update!(last_run_at: Time.current, last_error: e.message.truncate(250))
      "#{provider.name} : échec"
    end
    CveRating.refresh!(cves)
    "#{cves.size} CVE · #{results.join(" · ")}"
  end
end
