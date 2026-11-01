# Synchronizes an extension in the background, followed by its task.
class Integrations::SyncJob < ApplicationJob
  queue_as :default

  discard_on ActiveJob::DeserializationError

  def perform(integration, task = nil)
    task&.start!
    unless integration.enabled?
      task&.refresh!(result: "Extension désactivée : rien à faire")
      return
    end

    task&.refresh!(result: integration.sync!)
  rescue Integrations::Error => e
    task&.fail!(e.message)
  rescue StandardError => e
    task&.fail!("Erreur interne (#{e.class})")
    raise
  end
end
