class CreateBackgroundTasks < ActiveRecord::Migration[8.1]
  def change
    create_table :background_tasks do |t|
      t.string :kind, null: false
      t.string :label, null: false
      t.string :status, null: false, default: "queued"
      t.references :user, foreign_key: { on_delete: :nullify }
      t.references :automation, foreign_key: { on_delete: :nullify }
      t.text :result
      t.datetime :started_at
      t.datetime :finished_at
      t.timestamps
    end
    add_index :background_tasks, [ :status, :created_at ]
    add_index :background_tasks, :created_at

    create_table :background_task_items do |t|
      t.references :background_task, null: false, foreign_key: { on_delete: :cascade }
      t.references :server, foreign_key: { on_delete: :nullify }
      t.string :server_name, null: false
      t.string :status, null: false, default: "queued"
      t.text :message
      t.jsonb :details, null: false, default: {}
      t.datetime :started_at
      t.datetime :finished_at
      t.timestamps
    end
  end
end
