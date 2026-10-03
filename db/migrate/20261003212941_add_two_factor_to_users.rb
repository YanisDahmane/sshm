class AddTwoFactorToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :otp_secret, :text
    add_column :users, :otp_enabled_at, :datetime
    add_column :users, :otp_backup_codes, :jsonb, null: false, default: []
    add_column :users, :otp_last_used_at, :integer

    create_table :app_settings do |t|
      t.boolean :require_admin_two_factor, null: false, default: true

      t.timestamps
    end
  end
end
