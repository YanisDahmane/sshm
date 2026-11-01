# The rating of a CVE of the fleet, from the enabled providers: the average
# of their CVSS scores, its EPSS probability, whether CISA lists it as
# exploited. The severity it gives (`severity_for`) replaces the one of the
# distribution when that one did not rate the CVE ("unknown").
class CveRating < ApplicationRecord
  def self.severity_for(score)
    return "unknown" if score.nil?

    if score >= 9 then "critical"
    elsif score >= 7 then "high"
    elsif score >= 4 then "medium"
    else "low"
    end
  end

  def severity = self.class.severity_for(score)

  def self.for(cves) = where(cve: cves).index_by(&:cve)

  # Recomputes the ratings of `cves` (all those of the fleet by default) from
  # the scores of the enabled providers, then the severity in use of the
  # unrated rows, logging (and alerting on) those that became serious.
  def self.refresh!(cves = ServerVulnerability.distinct.pluck(:cve))
    providers = ScoreProvider.all_providers.select(&:enabled?)
    cvss = providers.select(&:cvss?).map(&:key)
    scores = CveScore.where(cve: cves, provider_key: providers.map(&:key)).pluck(:cve, :provider_key, :score, :data).group_by(&:first)
    now = Time.current
    rows = cves.map do |cve|
      entries = scores.fetch(cve, [])
      values = entries.select { |_, key, score| cvss.include?(key) && score }.map { |entry| entry[2].to_f }
      epss = entries.find { |_, key| key == "epss" }
      kev = entries.find { |_, key| key == "kev" }
      { cve: cve, score: (values.any? ? (values.sum / values.size).round(1) : nil), scores_count: values.size, epss: epss&.dig(2), epss_percentile: epss&.dig(3, "percentile"), exploited: kev&.dig(2).present?,
        exploited_since: kev&.dig(3, "date_added"), updated_at: now }
    end
    rows.each_slice(5000) { |slice| upsert_all(slice, unique_by: :cve) }
    apply_severities(cves)
  end

  # Severity in use of the rows the distribution did not rate.
  def self.apply_severities(cves)
    ratings = where(cve: cves).pluck(:cve, :score).to_h
    affected = ServerVulnerability.where(cve: cves, distro_severity: [ "unknown", nil ])
    before = serious_by_server
    affected.pluck(:id, :cve, :severity).group_by { |_, cve, _| severity_for(ratings[cve]) }.each do |severity, list|
      ids = list.reject { |_, _, current| current == severity }.map(&:first)
      ServerVulnerability.where(id: ids).update_all(severity: severity) if ids.any?
    end
    after = serious_by_server
    Server.where(id: (before.keys + after.keys).uniq).includes(:inventory_snapshots).find_each do |server|
      Vulnerabilities::Matcher.log_serious(server, after.fetch(server.id, Set.new) - before.fetch(server.id, Set.new))
      server.refresh_health!
    end
  end

  # { server_id => Set of the fixable CVEs at the alert severity }.
  def self.serious_by_server
    minimum = AppSetting.current.vulnerability_alert_severity
    return {} if minimum == "none"

    ServerVulnerability.fixable.at_least(minimum).distinct.pluck(:server_id, :cve).group_by(&:first).transform_values { |pairs| pairs.map(&:last).to_set }
  end
  private_class_method :serious_by_server
end
