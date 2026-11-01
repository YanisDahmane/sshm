require "test_helper"

class IntegrationSyncJobTest < ActiveJob::TestCase
  include IntegrationHelpers

  setup { Integration.registry = { "demo" => "DemoIntegration" } }
  teardown { Integration.registry = nil }

  test "synchronizes and completes its task" do
    integration = enable_demo
    task = integration.enqueue_sync!(user: nil)
    Integrations::SyncJob.perform_now(integration, task)
    assert_equal [ "succeeded", "3 éléments" ], [ task.reload.status, task.result ]
  end

  test "a service error fails the task without retrying" do
    integration = enable_demo(url: "https://bad.example")
    task = integration.enqueue_sync!(user: nil)
    Integrations::SyncJob.perform_now(integration, task)
    assert_equal [ "failed", "refusé (401)" ], [ task.reload.status, task.result ]
  end

  test "does nothing for a disabled extension" do
    integration = enable_demo
    integration.update!(enabled: false)
    task = BackgroundTask.enqueue!(kind: "integration", label: "Synchronisation Démo", servers: [], user: nil)
    Integrations::SyncJob.perform_now(integration, task)
    assert_equal [ "succeeded", "Extension désactivée : rien à faire" ], [ task.reload.status, task.result ]
  end
end
