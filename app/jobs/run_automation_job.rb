# Runs an automation, followed by its BackgroundTask when there is one (the
# quiet automations, every 15 minutes, have none).
class RunAutomationJob < ApplicationJob
  queue_as :default

  discard_on ActiveJob::DeserializationError

  def perform(automation, task = nil)
    task&.start!
    result = automation.run!(task: task)
    task&.refresh!(result: result)
  rescue StandardError => e
    task&.fail!("Erreur interne (#{e.class})")
    raise
  end
end
