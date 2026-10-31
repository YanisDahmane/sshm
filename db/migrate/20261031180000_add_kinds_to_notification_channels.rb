# Email, Discord and generic webhook channels, and the daily digest.
class AddKindsToNotificationChannels < ActiveRecord::Migration[8.1]
  def change
    change_column_null :notification_channels, :webhook_url, true
    add_column :notification_channels, :recipients, :text
    add_column :notification_channels, :signing_secret, :text
    add_column :notification_channels, :daily_digest, :boolean, null: false, default: false
    add_column :notification_channels, :last_digest_at, :datetime
  end
end
