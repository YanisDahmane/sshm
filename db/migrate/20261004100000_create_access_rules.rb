class CreateAccessRules < ActiveRecord::Migration[8.1]
  def change
    create_table :access_rules do |t|
      t.references :profile, foreign_key: { on_delete: :cascade }
      t.references :team, foreign_key: { on_delete: :cascade }
      t.references :server, foreign_key: { on_delete: :cascade }
      t.references :server_group, foreign_key: { on_delete: :cascade }
      t.string :unix_user
      t.references :created_by, foreign_key: { to_table: :users, on_delete: :nullify }
      t.timestamps
    end
    add_check_constraint :access_rules, "num_nonnulls(profile_id, team_id) = 1", name: "access_rules_one_subject"
    add_check_constraint :access_rules, "num_nonnulls(server_id, server_group_id) = 1", name: "access_rules_one_target"

    change_table :automations, bulk: true do |t|
      t.boolean :auto_fix, null: false, default: false
      t.jsonb :state, null: false, default: {}
    end
  end
end
