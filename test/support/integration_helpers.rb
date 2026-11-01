# A demo extension for the tests of the extensions framework, and helpers to
# register extensions for the duration of a test.
class DemoIntegration < Integrations::Base
  self.key = "demo"
  self.label = "Démo"
  self.description = "Extension de démonstration."

  # The text of its health reason, in both languages.
  I18n.backend.store_translations(:fr, demo: { alert: "Alerte de démonstration" })
  I18n.backend.store_translations(:en, demo: { alert: "Demo alert" })
  self.icon = :globe

  def self.fields
    [
      Field.new(key: :url, label: "URL", type: :url, required: true, placeholder: "https://demo.example"),
      Field.new(key: :api_key, label: "Clé API", secret: true, required: true),
      Field.new(key: :verify_ssl, label: "Vérifier le certificat", type: :boolean, default: true),
      Field.new(key: :products, label: "Produits", type: :checkboxes, options: [ [ "ip", "IP" ], [ "dns", "DNS" ] ], default: %w[ip], section: "Ressources"),
      Field.new(key: :threshold, label: "Seuil", type: :number, default: 14, section: "Alertes"),
      Field.new(key: :alert, label: "Alerter", type: :boolean, default: false, section: "Alertes")
    ]
  end

  def self.test_connection(integration)
    raise Integrations::Error, "hôte injoignable" if integration.value(:url).to_s.include?("bad")

    "3 éléments trouvés"
  end

  def self.sync(integration)
    raise Integrations::Error, "refusé (401)" if integration.value(:url).to_s.include?("bad")

    "3 éléments"
  end

  def self.server_tabs = [ { key: "demo", label: "Démo", count: ->(_server) { 2 } } ]

  def self.sidebar_links = [ { label: "Démo", path: :tasks_path, icon: :globe, controller: "demo" } ]

  def self.health_reasons(integration, _server)
    integration.value(:alert) ? [ Inventory::HealthStatus.reason("warn", "demo.alert") ] : []
  end
end

module IntegrationHelpers
  def with_integrations(registry = { "demo" => "DemoIntegration" })
    previous = Integration.registry
    Integration.registry = registry
    ActionController::Base.prepend_view_path(Rails.root.join("test/fixtures/views"))
    yield
  ensure
    Integration.registry = previous
  end

  def enable_demo(url: "https://demo.example", **settings)
    Integration.find_or_initialize_by(kind: "demo").tap do |integration|
      integration.update!(enabled: true, settings: { "url" => url }.merge(settings.stringify_keys), secrets: { "api_key" => "secret-key" })
    end
  end
end
