class AddSshStatusToServers < ActiveRecord::Migration[8.0]
  def change
    add_column :servers, :ssh_ok, :boolean
    add_column :servers, :ssh_checked_at, :datetime
  end
end
