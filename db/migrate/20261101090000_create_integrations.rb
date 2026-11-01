class CreateIntegrations < ActiveRecord::Migration[8.1]
  def change
    create_table :integrations do |t|
      t.string :kind, null: false, index: { unique: true }
      t.boolean :enabled, null: false, default: false
      t.jsonb :settings, null: false, default: {}
      t.text :secrets # encrypted JSON
      t.jsonb :state, null: false, default: {}
      t.datetime :last_synced_at
      t.text :last_error
      t.timestamps
    end

    # Manual matching of an external resource with a server (kept across
    # synchronizations): server = nil means "attached to no server".
    create_table :integration_links do |t|
      t.references :integration, null: false, foreign_key: { on_delete: :cascade }
      t.string :external_id, null: false
      t.references :server, foreign_key: { on_delete: :cascade }
      t.references :user, foreign_key: { on_delete: :nullify }
      t.timestamps
    end
    add_index :integration_links, %i[integration_id external_id], unique: true
  end
end
