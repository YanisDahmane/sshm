# Packages installed on each server (dpkg, snap, Docker images), replaced at
# each collection, so the whole fleet can be searched by package.
class CreateInventoryPackages < ActiveRecord::Migration[8.1]
  def change
    create_table :inventory_packages do |t|
      t.references :server, null: false, foreign_key: { on_delete: :cascade }
      t.string :manager, null: false
      t.string :name, null: false
      t.string :version
      t.string :arch
      t.string :available_version
      t.boolean :security, null: false, default: false
    end
    add_index :inventory_packages, :name
  end
end
