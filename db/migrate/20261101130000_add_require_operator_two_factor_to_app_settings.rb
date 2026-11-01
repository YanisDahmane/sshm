# Operators change the authorized_keys of the servers: their accounts deserve
# a second factor too (AUDIT.md S20).
class AddRequireOperatorTwoFactorToAppSettings < ActiveRecord::Migration[8.1]
  def change
    add_column :app_settings, :require_operator_two_factor, :boolean, null: false, default: true
  end
end
