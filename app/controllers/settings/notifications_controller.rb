module Settings
  # Notification channels (Slack webhooks) and the activity kinds they receive.
  class NotificationsController < ApplicationController
    def show
      @channels = NotificationChannel.order(:name)
    end
  end
end
