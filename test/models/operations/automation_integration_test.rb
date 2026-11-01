require "test_helper"

class AutomationIntegrationTest < ActiveSupport::TestCase
  include IntegrationHelpers

  setup { Integration.registry = { "demo" => "DemoIntegration" } }
  teardown { Integration.registry = nil }

  def demo_automation
    definition = Automation::Definition.new(key: :demo_sync, label: "Synchronisation Démo", description: "", default_interval: 15, integration: "demo")
    Automation.new(kind: "keys_scan", enabled: true, interval_minutes: 15).tap do |automation|
      automation.define_singleton_method(:definition) { definition }
    end
  end

  test "only available, and due, while its extension is enabled" do
    automation = demo_automation
    assert_not automation.available?
    assert_not automation.due?

    enable_demo
    assert automation.available?
    assert automation.due?
    assert Automation::KINDS.values.reject(&:integration).all?(&:available?), "the built-in automations are always available"
  end

  test "runs the synchronization, and reports a failure in its result" do
    automation = demo_automation
    automation.define_singleton_method(:update!) { |**| true }
    assert_equal "Extension désactivée : rien à faire", automation.run!

    enable_demo
    assert_equal "3 éléments", automation.run!

    enable_demo(url: "https://bad.example")
    assert_equal "Échec : refusé (401)", automation.run!
  end
end
