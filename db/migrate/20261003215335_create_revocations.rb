class CreateRevocations < ActiveRecord::Migration[8.1]
  def change
    create_table :revocations do |t|
      t.references :profile, foreign_key: { on_delete: :nullify }
      t.string :profile_name, null: false
      t.string :fingerprint, null: false
      t.text :key_blob, null: false
      t.references :started_by, foreign_key: { to_table: :users, on_delete: :nullify }
      t.boolean :delete_profile, null: false, default: false
      t.integer :servers_count, null: false, default: 0
      t.datetime :finished_at

      t.timestamps
    end

    create_table :revocation_steps do |t|
      t.references :revocation, null: false, foreign_key: { on_delete: :cascade }
      t.references :server, foreign_key: { on_delete: :nullify }
      t.string :server_name, null: false
      t.string :unix_user
      t.string :status, null: false
      t.text :error_message

      t.timestamps
    end
  end
end
