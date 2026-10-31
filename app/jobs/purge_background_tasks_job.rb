# Every day (config/recurring.yml): forgets the finished tasks older than 30 days.
class PurgeBackgroundTasksJob < ApplicationJob
  queue_as :default

  def perform
    BackgroundTask.expired.in_batches.delete_all # (items: ON DELETE CASCADE)
  end
end
