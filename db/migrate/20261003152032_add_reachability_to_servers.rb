class AddReachabilityToServers < ActiveRecord::Migration[8.0]
  def change
    add_column :servers, :reachable, :boolean
    add_column :servers, :last_checked_at, :datetime
  end
end
