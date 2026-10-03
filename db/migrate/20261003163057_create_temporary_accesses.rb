class CreateTemporaryAccesses < ActiveRecord::Migration[8.0]
  def change
    create_table :temporary_accesses do |t|
      t.references :server, null: false, foreign_key: { on_delete: :cascade }
      t.references :profile, foreign_key: { on_delete: :nullify }
      t.string :unix_user, null: false
      t.text :key_blob, null: false
      t.string :fingerprint, null: false
      t.datetime :expires_at, null: false
      t.datetime :ended_at

      t.timestamps
    end
    add_index :temporary_accesses, [ :server_id, :unix_user, :fingerprint ], unique: true, where: "ended_at IS NULL",
                                                                          name: "index_temporary_accesses_active_key"
    add_index :temporary_accesses, :expires_at, where: "ended_at IS NULL", name: "index_temporary_accesses_active_expiry"
  end
end
