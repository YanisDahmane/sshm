class AddAccountManagementToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :deactivated_at, :datetime
    add_reference :users, :profile, foreign_key: { on_delete: :nullify }, index: { unique: true, where: "profile_id IS NOT NULL" }

    # Devise trackable
    add_column :users, :sign_in_count, :integer, default: 0, null: false
    add_column :users, :current_sign_in_at, :datetime
    add_column :users, :last_sign_in_at, :datetime
    add_column :users, :current_sign_in_ip, :string
    add_column :users, :last_sign_in_ip, :string
  end
end
