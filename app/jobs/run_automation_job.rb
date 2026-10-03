class RunAutomationJob < ApplicationJob
  queue_as :default

  discard_on ActiveJob::DeserializationError

  def perform(automation)
    automation.run!
  end
end
