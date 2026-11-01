class CreateUptimeKumaMonitors < ActiveRecord::Migration[8.1]
  def change
    # Probes read from Uptime Kuma's /metrics, replaced at each synchronization.
    create_table :uptime_kuma_monitors do |t|
      t.string :monitor_id, null: false, index: { unique: true }
      t.string :name, null: false
      t.string :monitor_type
      t.string :url
      t.string :hostname
      t.integer :port
      t.jsonb :tags, null: false, default: []
      t.integer :status
      t.float :response_time_ms
      t.jsonb :uptime, null: false, default: {}
      t.jsonb :average_response_ms, null: false, default: {}
      t.integer :cert_days_remaining
      t.boolean :cert_valid
      t.references :server, foreign_key: { on_delete: :nullify }
      t.string :matched_by # ip, url, dns, name, manual
      t.string :matched_address
      t.datetime :status_changed_at
      t.timestamps
    end
  end
end
