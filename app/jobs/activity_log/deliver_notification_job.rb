class DeliverNotificationJob < ApplicationJob
  queue_as :default

  retry_on Notifications::DeliveryError, wait: :polynomially_longer, attempts: 5 do |job, error|
    job.arguments.first.record_delivery!(error: error.message)
  end
  discard_on ActiveJob::DeserializationError

  def perform(channel, activity)
    return unless channel.enabled? && channel.subscribed_to?(activity.kind)

    channel.notifier.deliver(channel, activity)
    channel.record_delivery!
  rescue Notifications::DeliveryError => e
    channel.record_delivery!(error: e.message)
    raise
  end
end
