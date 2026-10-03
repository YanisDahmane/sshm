class CreateNotificationChannels < ActiveRecord::Migration[8.0]
  def change
    create_table :notification_channels do |t|
      t.string :name, null: false
      t.string :kind, null: false, default: "slack"
      t.text :webhook_url, null: false
      t.jsonb :activity_kinds, null: false, default: []
      t.boolean :mention_channel, null: false, default: false
      t.boolean :enabled, null: false, default: true
      t.datetime :last_delivered_at
      t.text :last_error

      t.timestamps
    end
    add_index :notification_channels, :name, unique: true
  end
end
