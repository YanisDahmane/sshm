# Health history (kept 30 days, for the small curves), the health state of
# each server and the thresholds it is computed with.
class CreateInventoryHealthSamples < ActiveRecord::Migration[8.1]
  def change
    create_table :inventory_health_samples do |t|
      t.references :server, null: false, foreign_key: { on_delete: :cascade }, index: false
      t.datetime :collected_at, null: false
      t.float :load_percent
      t.float :memory_percent
      t.float :disk_percent
    end
    add_index :inventory_health_samples, %i[server_id collected_at]
    add_index :inventory_health_samples, :collected_at

    add_column :servers, :health_status, :string
    add_column :servers, :health_reasons, :jsonb, null: false, default: []

    change_table :app_settings, bulk: true do |t|
      t.integer :health_disk_warn, null: false, default: 80
      t.integer :health_disk_crit, null: false, default: 90
      t.integer :health_memory_warn, null: false, default: 90
      t.integer :health_memory_crit, null: false, default: 95
      t.decimal :health_load_warn, precision: 4, scale: 1, null: false, default: 2.0
    end
  end
end
