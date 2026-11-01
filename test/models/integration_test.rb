require "test_helper"

class IntegrationTest < ActiveSupport::TestCase
  include IntegrationHelpers

  setup { Integration.registry = { "demo" => "DemoIntegration" } }
  teardown { Integration.registry = nil }

  test "values: setting, secret or default" do
    integration = enable_demo
    assert_equal "https://demo.example", integration.value(:url)
    assert_equal "secret-key", integration.value(:api_key)
    assert_equal true, integration.value(:verify_ssl)
    assert_equal %w[ip], integration.value(:products)
    assert_raises(ArgumentError) { integration.value(:nope) }
  end

  test "secrets are encrypted in the database" do
    integration = enable_demo
    raw = Integration.connection.select_value("SELECT secrets FROM integrations WHERE id = #{integration.id}")
    assert_not_includes raw, "secret-key"
    assert_equal "secret-key", Integration.find(integration.id).secrets["api_key"]
  end

  test "assign_form casts the values and keeps a blank secret" do
    integration = enable_demo
    integration.assign_form("url" => " https://other.example ", "api_key" => "", "verify_ssl" => "0", "products" => [ "", "dns", "evil" ], "threshold" => "7")
    assert_equal [ "https://other.example", "secret-key", false, %w[dns], 7 ], %i[url api_key verify_ssl products threshold].map { |key| integration.value(key) }

    integration.assign_form("api_key" => "new-key")
    assert_equal "new-key", integration.value(:api_key)
    assert_equal false, integration.value(:alert), "an unchecked box is false"
  end

  test "required fields only to enable it" do
    integration = Integration.new(kind: "demo")
    assert integration.valid?
    integration.enabled = true
    assert_not integration.valid?
    assert_equal [ "URL : obligatoire pour activer l'extension", "Clé API : obligatoire pour activer l'extension" ], integration.errors.full_messages
  end

  test "unknown kind" do
    assert_not Integration.new(kind: "nope").valid?
  end

  test "registry helpers: all kinds, enabled ones, tabs, links and health reasons" do
    assert_equal [ "demo" ], Integration.all_kinds.map(&:kind)
    assert_not Integration.enabled?(:demo)
    assert_empty Integration.server_tabs

    integration = enable_demo(alert: true)
    assert Integration.enabled?(:demo)
    assert_equal [ "demo" ], Integration.server_tabs.map { |tab| tab[:key] }
    assert_equal integration, Integration.server_tabs.first[:integration]
    assert_equal [ "Démo" ], Integration.sidebar_links.map { |link| link[:label] }
    assert_equal [ "Alerte de démonstration" ], Integration.health_reasons(servers(:web)).map(&:text)

    Integration.registry = {}
    assert_not Integration.enabled?(:demo), "a kind no longer registered is never enabled"
  end

  test "sync! remembers the date, or the error logged once" do
    integration = enable_demo
    assert_equal "3 éléments", integration.sync!
    assert integration.last_synced_at
    assert_nil integration.last_error

    integration.update!(settings: integration.settings.merge("url" => "https://bad.example"))
    2.times { assert_raises(Integrations::Error) { integration.sync! } }
    assert_equal "refusé (401)", integration.reload.last_error
    assert_equal 1, Activity.of_kind(:integration_sync_failed).count

    integration.update!(settings: integration.settings.merge("url" => "https://demo.example"))
    integration.sync!
    assert_nil integration.reload.last_error
  end

  test "enqueue_sync! creates a followed task" do
    integration = enable_demo
    task = integration.enqueue_sync!(user: users(:one))
    assert_equal [ "integration", "Synchronisation Démo", "queued" ], [ task.kind, task.label, task.status ]
  end

  test "manual links" do
    integration = enable_demo
    integration.links.create!(external_id: "73", server: servers(:web))
    integration.links.create!(external_id: "74", server: nil)
    assert_equal({ "73" => servers(:web).id, "74" => nil }, integration.manual_links)
    assert_not integration.links.build(external_id: "73").valid?
  end
end
