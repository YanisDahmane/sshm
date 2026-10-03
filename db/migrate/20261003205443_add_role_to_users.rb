class AddRoleToUsers < ActiveRecord::Migration[8.1]
  def up
    add_column :users, :role, :string, null: false, default: "viewer"
    # Accounts created before roles existed had full access: keep it.
    execute "UPDATE users SET role = 'admin'"
  end

  def down
    remove_column :users, :role
  end
end
