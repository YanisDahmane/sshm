class CreateInvitations < ActiveRecord::Migration[8.1]
  def change
    create_table :invitations do |t|
      t.string :email, null: false
      t.string :role, null: false, default: "viewer"
      t.string :token, null: false
      t.references :invited_by, null: false, foreign_key: { to_table: :users }
      t.references :user, foreign_key: { on_delete: :nullify }
      t.datetime :expires_at, null: false
      t.datetime :accepted_at
      t.datetime :revoked_at

      t.timestamps
    end
    add_index :invitations, :token, unique: true
    add_index :invitations, :email
  end
end
