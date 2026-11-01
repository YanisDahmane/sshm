# OVHcloud (read-only API keys): IP blocks with their reverse, network
# firewall and anti-DDoS, DNS records, dedicated servers, VPS and Public
# Cloud instances, attached to the servers they belong to. Each product and
# each alert is chosen in the extension's settings.
class Integrations::Ovh < Integrations::Base
  self.key = "ovh"
  self.label = "OVHcloud"
  self.description = "Vos ressources OVHcloud rattachées aux serveurs : service (offre, datacenter, expiration), IP et reverse, firewall réseau et anti-DDoS, " \
                     "enregistrements DNS qui pointent vers chaque serveur. Clé API en lecture seule."
  self.icon = :globe
  self.default_interval = 360

  class << self
    def fields
      [
        Integrations::Field.new(key: :endpoint, label: "Point d'accès", type: :select, default: "ovh-eu",
                  options: [ [ "OVHcloud Europe (ovh-eu)", "ovh-eu" ], [ "OVHcloud Canada (ovh-ca)", "ovh-ca" ], [ "OVHcloud US (ovh-us)", "ovh-us" ] ]),
        Integrations::Field.new(key: :application_key, label: "Application Key", required: true),
        Integrations::Field.new(key: :application_secret, label: "Application Secret", secret: true, required: true),
        Integrations::Field.new(key: :consumer_key, label: "Consumer Key", secret: true, required: true,
                  hint: "créée avec seulement des droits GET : voir « Droits à donner à la clé API »."),

        Integrations::Field.new(key: :products, label: "Ressources à lire", type: :checkboxes, section: "Ressources",
                  options: Integrations::Ovh::Fetch::PRODUCTS, default: Integrations::Ovh::Fetch::PRODUCTS.map(&:first)),
        Integrations::Field.new(key: :zones, label: "Zones DNS", type: :list, default: [], section: "Ressources", placeholder: "example.com, example.fr",
                  hint: "vide = toutes les zones du compte."),
        Integrations::Field.new(key: :projects, label: "Projets Public Cloud", type: :list, default: [], section: "Ressources", placeholder: "identifiants de projets",
                  hint: "vide = tous les projets."),

        Integrations::Field.new(key: :alert_expiring, label: "Service OVH bientôt expiré", type: :boolean, default: true, section: "Alertes"),
        Integrations::Field.new(key: :expiring_days, label: "Seuil d'expiration (jours)", type: :number, default: 30, section: "Alertes"),
        Integrations::Field.new(key: :expiring_ignore_auto_renew, label: "Ignorer les services en renouvellement automatique", type: :boolean, default: true, section: "Alertes"),
        Integrations::Field.new(key: :alert_firewall_disabled, label: "Firewall réseau OVH désactivé sur une IP d'un serveur", type: :boolean, default: false, section: "Alertes"),
        Integrations::Field.new(key: :alert_reverse_mismatch, label: "Reverse DNS absent ou différent du hostname", type: :boolean, default: false, section: "Alertes"),
        Integrations::Field.new(key: :alert_server_without_dns, label: "Serveur avec une IP OVH mais aucun enregistrement DNS", type: :boolean, default: false, section: "Alertes"),
        Integrations::Field.new(key: :alert_dns_outside, label: "Enregistrement DNS vers une IP hors du parc", type: :boolean, default: false, section: "Alertes"),
        Integrations::Field.new(key: :alert_unmanaged_service, label: "Service OVH rattaché à aucun serveur du parc", type: :boolean, default: false, section: "Alertes",
                  hint: "une machine payée mais pas suivie par Elio.")
      ]
    end

    def client(integration)
      Integrations::Ovh::Client.new(endpoint: integration.value(:endpoint), application_key: integration.value(:application_key),
                                    application_secret: integration.value(:application_secret), consumer_key: integration.value(:consumer_key))
    end

    # Checks the key and its rights: every chosen product readable, and warns
    # when the key could change something (a right other than GET).
    def test_connection(integration)
      credential = client(integration).get("/auth/currentCredential")
      rules = Array(credential["rules"])
      writes = rules.reject { |rule| rule["method"] == "GET" }.map { |rule| "#{rule["method"]} #{rule["path"]}" }
      missing = Integrations::Ovh::Fetch.rights(products(integration)).reject do |path|
        rules.any? { |rule| rule["method"].in?(%w[GET ALL]) && File.fnmatch(rule["path"], path) }
      end
      message = "clé valide (#{credential["status"] || "validée"})"
      message += ". Droits manquants : #{missing.map { |path| "GET #{path}" }.join(", ")}" if missing.any?
      message += ". ⚠ Cette clé permet aussi d'écrire (#{writes.first(4).join(", ")}) : refaites-en une en lecture seule" if writes.any?
      message
    end

    def sync(integration)
      resources = Integrations::Ovh::Fetch.new(client(integration), products: products(integration), zones: integration.value(:zones),
                                               projects: integration.value(:projects)).call
      Integrations::Ovh::Sync.new(integration, resources).call
    end

    def products(integration) = Array(integration.value(:products))

    # Rights to give to the API key, and the prefilled token creation page.
    def rights(integration) = Integrations::Ovh::Fetch.rights(products(integration))

    def token_url(integration)
      base = Integrations::Ovh::Client::TOKEN_PAGES.fetch(integration.value(:endpoint).to_s, Integrations::Ovh::Client::TOKEN_PAGES["ovh-eu"])
      "#{base}?#{rights(integration).map { |path| "GET=#{path}" }.join("&")}" # (paths are made of / and * only, like in OVH docs)
    end

    def server_tabs = [ { key: "ovh", label: "OVH", count: ->(server) { server.ovh_resources.size.nonzero? } } ]

    def sidebar_links = [ { label: "OVHcloud", path: :ovh_path, icon: :globe, controller: "ovh" } ]

    def help_partial = "integrations/ovh/help"

    def expiring_services(integration)
      scope = OvhResource.services.where(expires_at: ..integration.value(:expiring_days).to_i.days.from_now.to_date)
      integration.value(:expiring_ignore_auto_renew) ? scope.where("NOT COALESCE((ovh_resources.data->>'renew_automatic')::boolean, false)") : scope
    end

    # A/AAAA records whose IP belongs to no server of the fleet.
    def records_outside_fleet = OvhResource.of_kind("dns_record").unattached.where("ovh_resources.data->>'type' IN ('A', 'AAAA')")

    def health_reasons(integration, server)
      return [] unless integration.last_synced_at

      resources = server.ovh_resources.to_a
      return [] if resources.empty?

      reasons = []
      if integration.value(:alert_expiring)
        expiring = expiring_services(integration).where(server: server)
        expiring.each { |service| reasons << reason(service.days_left.to_i <= 7 ? "crit" : "warn", "Service OVH « #{service.name} » : expire dans #{service.days_left} j") }
      end
      ip_blocks = resources.select { |resource| resource.kind == "ip" }
      if integration.value(:alert_firewall_disabled)
        disabled = ip_blocks.flat_map { |block| Array(block.data["firewall"]).select { |_ip, firewall| firewall["enabled"] == false }.map(&:first) }
        missing = ip_blocks.select { |block| block.data.key?("firewall") && block.data["firewall"].empty? }.map(&:name)
        (disabled + missing).uniq.each { |ip| reasons << reason("warn", "Firewall réseau OVH désactivé sur #{ip}") }
      end
      if integration.value(:alert_reverse_mismatch) && server.hostname.present?
        ip_blocks.each do |block|
          Array(block.data["reverse"]).each do |ip, reverse|
            next if reverse.to_s.casecmp?(server.hostname)

            reasons << reason("warn", reverse.blank? ? "Pas de reverse DNS pour #{ip}" : "Reverse DNS de #{ip} (#{reverse}) ≠ hostname")
          end
        end
      end
      if integration.value(:alert_server_without_dns) && ip_blocks.any? && resources.none? { |resource| resource.kind == "dns_record" }
        reasons << reason("warn", "Aucun enregistrement DNS OVH ne pointe vers ce serveur")
      end
      reasons
    end

    private

    def reason(tone, text) = Inventory::HealthStatus::Reason.new(tone, text)
  end
end
