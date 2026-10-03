module SlackHelpers
  WEBHOOK = "https://hooks.slack.com/services/T000/B000/XXXXXXXXXXXXXXXXXXXXXXXX".freeze

  def create_channel(name: "#ops", activity_kinds: %w[unknown_key_detected ssh_access_lost], **attributes)
    NotificationChannel.create!(name: name, webhook_url: WEBHOOK, activity_kinds: activity_kinds, **attributes)
  end
end
