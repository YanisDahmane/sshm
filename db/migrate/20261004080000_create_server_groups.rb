class CreateServerGroups < ActiveRecord::Migration[8.1]
  def change
    create_table :server_groups do |t|
      t.string :name, null: false
      t.string :color, null: false, default: "slate"
      t.timestamps
    end
    add_index :server_groups, "lower(name)", unique: true, name: "index_server_groups_on_lower_name"

    create_table :server_group_memberships do |t|
      t.references :server, null: false, foreign_key: { on_delete: :cascade }
      t.references :server_group, null: false, foreign_key: { on_delete: :cascade }
      t.timestamps
    end
    add_index :server_group_memberships, %i[server_group_id server_id], unique: true
  end
end
