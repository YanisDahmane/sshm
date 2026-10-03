class CreateAccountSnapshots < ActiveRecord::Migration[8.0]
  def change
    create_table :account_snapshots do |t|
      t.references :server, null: false, foreign_key: { on_delete: :cascade }
      t.string :unix_user, null: false
      t.text :content, null: false, default: ""
      t.datetime :read_at, null: false

      t.timestamps
    end
    add_index :account_snapshots, [ :server_id, :unix_user ], unique: true
  end
end
