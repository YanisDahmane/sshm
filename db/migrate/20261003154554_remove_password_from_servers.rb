class RemovePasswordFromServers < ActiveRecord::Migration[8.0]
  def change
    remove_column :servers, :password, :text
  end
end
