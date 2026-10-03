class CreateActivities < ActiveRecord::Migration[8.0]
  def change
    create_table :activities do |t|
      t.string :kind, null: false
      t.references :user, foreign_key: { on_delete: :nullify }
      t.references :server, foreign_key: { on_delete: :nullify }
      t.references :profile, foreign_key: { on_delete: :nullify }
      t.string :unix_user
      t.jsonb :data, null: false, default: {}

      t.timestamps
    end
    add_index :activities, :kind
    add_index :activities, :created_at
  end
end
