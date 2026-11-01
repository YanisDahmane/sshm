class AddIpAddressesToServers < ActiveRecord::Migration[8.1]
  def change
    # Collected by the network inventory, and added by hand (NAT, floating IP…).
    add_column :servers, :ip_addresses, :jsonb, null: false, default: []
    add_column :servers, :extra_addresses, :jsonb, null: false, default: []
    add_index :servers, :ip_addresses, using: :gin
  end
end
