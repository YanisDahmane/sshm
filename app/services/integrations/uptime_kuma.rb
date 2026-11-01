# Uptime Kuma: reads the probes from its /metrics page (API key, read-only),
# attaches each one to the server it watches (Integrations::UptimeKuma::Matcher)
# and raises the alerts chosen in the extension's settings.
class Integrations::UptimeKuma < Integrations::Base
  self.key = "uptime_kuma"
  self.label = "Uptime Kuma"
  self.description = "Les sondes de votre instance Uptime Kuma, rattachées aux serveurs qu'elles surveillent : onglet « Sondes » sur chaque serveur, " \
                     "serveurs sans sonde, sondes hors ligne et certificats. Lecture seule, avec une clé API."
  self.icon = :signal
  self.default_interval = 15

  WINDOWS = [ [ "1d", "24 heures" ], [ "30d", "30 jours" ], [ "365d", "1 an" ] ].freeze

  class << self
    def fields
      [
        Integrations::Field.new(key: :url, label: "Adresse de l'instance", type: :url, required: true, placeholder: "https://uptime.example.com",
                  hint: "Elio lit <adresse>/metrics. En https de préférence : en http, la clé API circule en clair."),
        Integrations::Field.new(key: :api_key, label: "Clé API", secret: true, required: true, hint: "Uptime Kuma → Paramètres → Clés API. Elle ne donne accès qu'à /metrics."),
        Integrations::Field.new(key: :allow_self_signed, label: "Accepter un certificat auto-signé", type: :boolean, default: false,
                  hint: "seulement pour une instance interne dont vous connaissez le certificat."),

        Integrations::Field.new(key: :match_by_ip, label: "Par adresse IP", type: :boolean, default: true, section: "Rattachement des sondes aux serveurs",
                  hint: "la cible de la sonde est une adresse d'un serveur (publique, réseau local, WireGuard…)."),
        Integrations::Field.new(key: :match_by_host, label: "Par nom d'hôte", type: :boolean, default: true, section: "Rattachement des sondes aux serveurs",
                  hint: "l'hôte de la sonde ou de son URL est le hostname ou l'hôte SSH d'un serveur."),
        Integrations::Field.new(key: :resolve_dns, label: "Résoudre les noms en DNS", type: :boolean, default: false, section: "Rattachement des sondes aux serveurs",
                  hint: "pour les sondes HTTP d'un site hébergé sur un serveur (ex. https://app.example.com → son IP)."),
        Integrations::Field.new(key: :match_by_name, label: "Par le nom de la sonde", type: :boolean, default: true, section: "Rattachement des sondes aux serveurs",
                  hint: "le nom du serveur apparaît en mot entier dans celui de la sonde (ex. « [SRV] FR-UTILS-1 »)."),

        Integrations::Field.new(key: :alert_no_monitor, label: "Serveur sans aucune sonde", type: :boolean, default: true, section: "Alertes"),
        Integrations::Field.new(key: :no_monitor_ignored_groups, label: "Groupes dispensés de sonde", type: :checkboxes, default: [], section: "Alertes",
                  options: ServerGroup.order(:name).map { |group| [ group.id.to_s, group.name ] }),
        Integrations::Field.new(key: :alert_down, label: "Sonde hors ligne / de retour", type: :boolean, default: false, section: "Alertes",
                  hint: "complète les notifications d'Uptime Kuma sans les remplacer."),
        Integrations::Field.new(key: :alert_cert, label: "Certificat bientôt expiré", type: :boolean, default: false, section: "Alertes"),
        Integrations::Field.new(key: :cert_days, label: "Seuil du certificat (jours)", type: :number, default: 14, section: "Alertes"),
        Integrations::Field.new(key: :alert_uptime, label: "Disponibilité sous un seuil", type: :boolean, default: false, section: "Alertes"),
        Integrations::Field.new(key: :uptime_threshold, label: "Seuil de disponibilité (%)", type: :number, default: 99, section: "Alertes"),
        Integrations::Field.new(key: :uptime_window, label: "Sur", type: :select, options: WINDOWS.map(&:reverse), default: "30d", section: "Alertes"),
        Integrations::Field.new(key: :alert_maintenance, label: "Sonde en maintenance depuis longtemps", type: :boolean, default: false, section: "Alertes"),
        Integrations::Field.new(key: :maintenance_days, label: "Seuil de maintenance (jours)", type: :number, default: 7, section: "Alertes")
      ]
    end

    def test_connection(integration)
      result = fetch(integration)
      message = "#{result.monitors.size} sonde(s) trouvée(s)#{" (Uptime Kuma #{result.version})" if result.version}"
      message += ". ⚠ Adresse en http : la clé API circule en clair sur le réseau, préférez https" if integration.value(:url).to_s.start_with?("http://")
      message
    end

    def sync(integration)
      result = fetch(integration)
      Integrations::UptimeKuma::Sync.new(integration, result).call
    end

    def server_tabs = [ { key: "monitors", label: "Sondes", count: ->(server) { server.uptime_kuma_monitors.size } } ]

    def sidebar_links = [ { label: "Sondes", path: :monitors_path, icon: :signal, controller: "monitors" } ]

    def help_partial = "integrations/uptime_kuma/help"

    def health_reasons(integration, server)
      return [] unless integration.last_synced_at

      monitors = server.uptime_kuma_monitors.to_a
      reasons = []
      if monitors.empty?
        ignored = Array(integration.value(:no_monitor_ignored_groups)).map(&:to_i)
        reasons << reason("warn", "Aucune sonde Uptime Kuma") if integration.value(:alert_no_monitor) && (server.server_group_ids & ignored).empty?
        return reasons
      end

      monitors.each do |monitor|
        reasons << reason("crit", "Sonde « #{monitor.name} » hors ligne") if integration.value(:alert_down) && monitor.down?
        if integration.value(:alert_cert) && monitor.cert_days_remaining && monitor.cert_days_remaining <= integration.value(:cert_days).to_i
          reasons << reason(monitor.cert_days_remaining <= 0 || monitor.cert_valid == false ? "crit" : "warn",
                            monitor.cert_days_remaining <= 0 ? "Certificat de « #{monitor.name} » expiré" : "Certificat de « #{monitor.name} » : expire dans #{monitor.cert_days_remaining} j")
        end
        window = integration.value(:uptime_window)
        ratio = monitor.uptime_ratio(window)
        if integration.value(:alert_uptime) && ratio && ratio * 100 < integration.value(:uptime_threshold).to_f
          label = WINDOWS.to_h.fetch(window, window)
          reasons << reason("warn", "Disponibilité de « #{monitor.name} » sur #{label} : #{format("%.2f", ratio * 100).sub(".", ",")} %")
        end
        if integration.value(:alert_maintenance) && monitor.state == "maintenance" && monitor.status_changed_at &&
           monitor.status_changed_at < integration.value(:maintenance_days).to_i.days.ago
          reasons << reason("warn", "Sonde « #{monitor.name} » en maintenance depuis plus de #{integration.value(:maintenance_days).to_i} jours")
        end
      end
      reasons
    end

    def fetch(integration)
      result = Integrations::Http.get("#{integration.value(:url).to_s.chomp("/")}/metrics", service: "Uptime Kuma", basic_auth: [ "", integration.value(:api_key).to_s ],
                                      verify_ssl: !integration.value(:allow_self_signed))
      parsed = Integrations::UptimeKuma::Metrics.parse(result)
      raise Integrations::Error, "La réponse ne ressemble pas à la page /metrics d'Uptime Kuma" if parsed.monitors.empty? && parsed.version.nil?

      parsed
    end

    private

    def reason(tone, text) = Inventory::HealthStatus::Reason.new(tone, text)
  end
end
