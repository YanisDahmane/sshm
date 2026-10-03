class CreateSshKeys < ActiveRecord::Migration[8.0]
  def change
    create_table :ssh_keys do |t|
      t.text :public_key, null: false
      t.text :private_key, null: false
      t.string :fingerprint, null: false

      t.timestamps
    end
  end
end
