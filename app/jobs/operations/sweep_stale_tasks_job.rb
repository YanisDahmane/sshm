# Every 15 minutes (config/recurring.yml): finishes the tasks whose job no
# longer exists (StaleTasks). Only with Solid Queue, the only adapter whose
# jobs can be looked up.
class SweepStaleTasksJob < ApplicationJob
  queue_as :default

  def perform
    return unless ActiveJob::Base.queue_adapter.is_a?(ActiveJob::QueueAdapters::SolidQueueAdapter)

    StaleTasks.call
  end
end
