# Summary of the system found by the inventory, to show and filter the fleet.
class AddOsToServers < ActiveRecord::Migration[8.1]
  def change
    add_column :servers, :os_name, :string
    add_column :servers, :os_id, :string
    add_column :servers, :os_version, :string
  end
end
