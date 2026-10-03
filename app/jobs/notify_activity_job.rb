# Sends an activity to every enabled channel subscribed to its kind. Each
# channel is delivered by its own job so one failing webhook does not block
# or repeat the others.
class NotifyActivityJob < ApplicationJob
  queue_as :default

  discard_on ActiveJob::DeserializationError

  def perform(activity)
    NotificationChannel.subscribed_to(activity.kind).find_each do |channel|
      DeliverNotificationJob.perform_later(channel, activity)
    end
  end
end
