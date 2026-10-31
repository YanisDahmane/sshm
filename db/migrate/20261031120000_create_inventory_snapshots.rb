# Last known inventory of each server, one row per category (os, health,
# packages, services, ports), plus a summary on the server for the fleet list.
class CreateInventorySnapshots < ActiveRecord::Migration[8.1]
  def change
    create_table :inventory_snapshots do |t|
      t.references :server, null: false, foreign_key: { on_delete: :cascade }
      t.string :category, null: false
      t.jsonb :data, null: false, default: {}
      t.string :status, null: false
      t.text :message
      t.boolean :privileged, null: false, default: false
      t.datetime :collected_at
      t.datetime :checked_at, null: false
      t.timestamps
    end
    add_index :inventory_snapshots, %i[server_id category], unique: true

    add_column :servers, :privilege, :string
    add_column :servers, :inventoried_at, :datetime
  end
end
