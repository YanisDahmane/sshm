class CreateServers < ActiveRecord::Migration[8.0]
  def change
    create_table :servers do |t|
      t.string :name, null: false
      t.string :host, null: false
      t.integer :port, null: false, default: 22
      t.string :username, null: false
      t.text :password

      t.timestamps
    end
    add_index :servers, :name, unique: true
  end
end
