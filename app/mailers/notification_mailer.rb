# Emails of the email notification channels.
class NotificationMailer < ApplicationMailer
  def activity(channel, activity)
    @activity = activity
    mail to: channel.recipient_list, subject: "[Elio] #{activity.label} : #{activity.summary.truncate(120)}"
  end

  def test(channel)
    @channel = channel
    mail to: channel.recipient_list, subject: "[Elio] Test du canal « #{channel.name} »"
  end

  def digest(channel, digest)
    @digest = digest
    mail to: channel.recipient_list, subject: "[Elio] #{digest.title}"
  end
end
