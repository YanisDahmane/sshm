# Definition of an extension (see Integration): its form fields, connection
# test, synchronization, and what it adds to the interface. Subclasses set
# the class attributes and override the hooks they need.
class Integrations::Base
  # A field of the extension's settings form. `secret`: stored encrypted,
  # never sent back to the browser (blank = unchanged). `section`: heading of
  # the form ("Connexion", "Rattachement", "Alertes"…).
  Field = Data.define(:key, :label, :type, :secret, :hint, :default, :required, :options, :section, :placeholder) do
    def initialize(key:, label:, type: :text, secret: false, hint: nil, default: nil, required: false, options: nil, section: "Connexion", placeholder: nil)
      super(key: key.to_s, label:, type:, secret:, hint:, default:, required:, options:, section:, placeholder:)
    end

    def boolean? = type == :boolean

    # Value from the form (strings) to the stored type.
    def cast(value)
      case type
      when :boolean then ActiveModel::Type::Boolean.new.cast(value) || false
      when :number then value.to_s.strip.presence && value.to_s.strip.to_f.then { |number| number == number.to_i ? number.to_i : number }
      when :list then value.is_a?(Array) ? value.compact_blank : value.to_s.split(/[\s,;]+/).compact_blank
      when :checkboxes then Array(value).compact_blank & options.map { |option| option.first.to_s }
      else value.to_s.strip.presence
      end
    end
  end

  class_attribute :key, :label, :description, :icon, :default_interval, instance_writer: false
  self.icon = :bolt
  self.default_interval = 360

  class << self
    def fields = []

    # Raises Integrations::Error with a readable message; returns what was found ("12 sondes").
    def test_connection(_integration) = raise(NotImplementedError)

    # Reads the external service and stores what it found; returns a summary.
    def sync(_integration) = raise(NotImplementedError)

    # Tabs added to the server page: [{ key:, label:, count: ->(server) {} }], rendered with
    # the partial "integrations/<key>/server_tab".
    def server_tabs = []

    # Links added to the sidebar: [{ label:, path: (helper name), icon: }].
    def sidebar_links = []

    # Health reasons of a server (HealthStatus::Reason), when the extension raises alerts.
    def health_reasons(_integration, _server) = []

    # Help shown on the settings page (partial "integrations/<key>/help"), or nil.
    def help_partial = nil
  end
end
