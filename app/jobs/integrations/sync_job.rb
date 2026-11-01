# Synchronizes an extension in the background, followed by its task.
class Integrations::SyncJob < ApplicationJob
  queue_as :default

  discard_on ActiveJob::DeserializationError

  def perform(integration, task = nil)
    task&.start!
    unless integration.enabled?
      task&.refresh!(result: I18n.t("integrations.sync_job.turned_off"))
      return
    end

    task&.refresh!(result: integration.sync!)
  rescue Integrations::Error => e
    task&.fail!(e.message)
  rescue StandardError => e
    task&.fail!(I18n.t("integrations.sync_job.internal_error", class: e.class))
    raise
  end
end
