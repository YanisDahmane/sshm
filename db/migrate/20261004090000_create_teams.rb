class CreateTeams < ActiveRecord::Migration[8.1]
  def change
    create_table :teams do |t|
      t.string :name, null: false
      t.text :description
      t.timestamps
    end
    add_index :teams, "lower(name)", unique: true, name: "index_teams_on_lower_name"

    create_table :team_memberships do |t|
      t.references :team, null: false, foreign_key: { on_delete: :cascade }
      t.references :profile, null: false, foreign_key: { on_delete: :cascade }
      t.timestamps
    end
    add_index :team_memberships, %i[team_id profile_id], unique: true
  end
end
