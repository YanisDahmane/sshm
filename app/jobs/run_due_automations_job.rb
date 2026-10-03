# Runs every minute (config/recurring.yml): starts the enabled automations
# whose interval has elapsed. last_run_at is set before enqueuing so a slow
# run is not started twice by the next tick.
class RunDueAutomationsJob < ApplicationJob
  queue_as :default

  def perform
    Automation.where(enabled: true).select(&:due?).each do |automation|
      automation.update!(last_run_at: Time.current)
      RunAutomationJob.perform_later(automation)
    end
  end
end
