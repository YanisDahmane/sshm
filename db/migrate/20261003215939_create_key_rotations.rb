class CreateKeyRotations < ActiveRecord::Migration[8.1]
  def change
    add_column :ssh_keys, :state, :string, null: false, default: "active"

    create_table :key_rotations do |t|
      t.references :old_key, foreign_key: { to_table: :ssh_keys, on_delete: :nullify }
      t.references :new_key, foreign_key: { to_table: :ssh_keys, on_delete: :nullify }
      t.references :started_by, foreign_key: { to_table: :users, on_delete: :nullify }
      t.integer :servers_count, null: false, default: 0
      t.boolean :forced, null: false, default: false
      t.datetime :finished_at
      t.datetime :activated_at

      t.timestamps
    end

    create_table :key_rotation_steps do |t|
      t.references :key_rotation, null: false, foreign_key: { on_delete: :cascade }
      t.references :server, foreign_key: { on_delete: :nullify }
      t.string :server_name, null: false
      t.string :status, null: false
      t.string :phase
      t.text :error_message

      t.timestamps
    end
  end
end
