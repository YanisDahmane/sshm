# Daily digest of a notification channel: the fleet state and the activities
# of the period (yesterday by default), the warnings and critical ones listed.
class NotificationDigest
  HIGHLIGHTS = 10

  attr_reader :from, :to

  def initialize(from: Date.yesterday.beginning_of_day, to: Date.yesterday.end_of_day)
    @from = from
    @to = to
  end

  def title = I18n.t("notification_digest.title", date: (I18n.l(from.to_date, format: :long)))

  def activities = @activities ||= Activity.recent.where(created_at: from..to).includes(:user, :server).to_a

  def counts = %i[critical warning info].index_with { |severity| activities.count { |activity| activity.severity == severity } }

  def summary = @summary ||= FleetSummary.new(Server.includes(:inventory_snapshots))

  def lines
    lines = [ I18n.t("notification_digest.fleet", online: summary.online, total: summary.total, to_watch: summary.to_watch, critical: summary.critical, updates: I18n.t("notification_digest.security_updates", count: summary.security_updates)),
              I18n.t("notification_digest.activity", events: I18n.t("notification_digest.events", count: activities.size), critical: counts[:critical], warning: counts[:warning]) ]
    if (cves = ServerVulnerability.distinct.count(:cve)).positive?
      fixable = ServerVulnerability.fixable.distinct.count(:cve)
      serious = ServerVulnerability.fixable.at_least("high").distinct.count(:cve)
      lines << I18n.t("notification_digest.vulnerabilities", cves: cves, fixable: fixable, serious: serious, servers: I18n.t("count.servers", count: ServerVulnerability.distinct.count(:server_id)))
    end
    highlights = activities.reject { |activity| activity.severity == :info }.first(HIGHLIGHTS)
    lines += highlights.map { |activity| "- #{activity.label} : #{activity.summary}" }
    lines << I18n.t("notification_digest.nothing") if activities.empty?
    lines
  end
end
