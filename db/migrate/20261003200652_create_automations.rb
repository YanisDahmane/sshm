class CreateAutomations < ActiveRecord::Migration[8.0]
  def change
    create_table :automations do |t|
      t.string :kind, null: false
      t.boolean :enabled, null: false, default: false
      t.integer :interval_minutes, null: false
      t.datetime :last_run_at
      t.string :last_result

      t.timestamps
    end
    add_index :automations, :kind, unique: true
  end
end
