# A notification could not be delivered (webhook answer, network, SMTP…);
# DeliverNotificationJob retries and remembers the message on the channel.
class Notifications::DeliveryError < StandardError; end
