# Daily digest of a notification channel: the fleet state and the activities
# of the period (yesterday by default), the warnings and critical ones listed.
class NotificationDigest
  HIGHLIGHTS = 10

  attr_reader :from, :to

  def initialize(from: Date.yesterday.beginning_of_day, to: Date.yesterday.end_of_day)
    @from = from
    @to = to
  end

  def title = "Résumé Elio du #{I18n.l(from.to_date, format: :long)}"

  def activities = @activities ||= Activity.recent.where(created_at: from..to).includes(:user, :server).to_a

  def counts = %i[critical warning info].index_with { |severity| activities.count { |activity| activity.severity == severity } }

  def summary = @summary ||= FleetSummary.new(Server.includes(:inventory_snapshots))

  def lines
    lines = [ "Parc : #{summary.online}/#{summary.total} en ligne, #{summary.to_watch} à surveiller, #{summary.critical} critique(s), " \
              "#{summary.security_updates} mise(s) à jour de sécurité en attente.",
              "Activité : #{activities.size} événement(s) dont #{counts[:critical]} critique(s) et #{counts[:warning]} avertissement(s)." ]
    if (cves = ServerVulnerability.distinct.count(:cve)).positive?
      fixable = ServerVulnerability.fixable.distinct.count(:cve)
      serious = ServerVulnerability.fixable.at_least("high").distinct.count(:cve)
      lines << "Vulnérabilités : #{cves} connue(s), #{fixable} corrigeable(s) dont #{serious} grave(s), sur #{ServerVulnerability.distinct.count(:server_id)} serveur(s)."
    end
    highlights = activities.reject { |activity| activity.severity == :info }.first(HIGHLIGHTS)
    lines += highlights.map { |activity| "- #{activity.label} : #{activity.summary}" }
    lines << "Rien à signaler." if activities.empty?
    lines
  end
end
