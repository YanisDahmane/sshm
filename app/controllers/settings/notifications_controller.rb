module Settings
  # Notification channels (Slack webhooks) and the activity kinds they receive.
  class NotificationsController < ApplicationController
    require_permission :administer

    def show
      @channels = NotificationChannel.order(:name)
    end
  end
end
