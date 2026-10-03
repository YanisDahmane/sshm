class CreateAccessRequests < ActiveRecord::Migration[8.1]
  def change
    create_table :access_requests do |t|
      t.references :requester, null: false, foreign_key: { to_table: :users, on_delete: :cascade }
      t.references :profile, foreign_key: { on_delete: :nullify }
      t.references :server, null: false, foreign_key: { on_delete: :cascade }
      t.string :unix_user, null: false
      t.integer :duration_minutes, null: false
      t.text :reason, null: false
      t.string :status, null: false, default: "pending"
      t.references :decided_by, foreign_key: { to_table: :users, on_delete: :nullify }
      t.datetime :decided_at
      t.text :decision_note
      t.timestamps
    end
    add_index :access_requests, :status
  end
end
