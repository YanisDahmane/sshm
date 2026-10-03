class CreateProfiles < ActiveRecord::Migration[8.0]
  def change
    create_table :profiles do |t|
      t.string :name, null: false
      t.text :public_key, null: false
      t.string :fingerprint, null: false

      t.timestamps
    end
    add_index :profiles, :name, unique: true
    add_index :profiles, :fingerprint, unique: true
  end
end
