# The models check uniqueness case-insensitively; the database now does too,
# so two requests at the same time cannot create "Web" and "web".
class CaseInsensitiveUniqueNames < ActiveRecord::Migration[8.1]
  def change
    remove_index :servers, :name, unique: true, name: "index_servers_on_name"
    add_index :servers, "lower(name)", unique: true, name: "index_servers_on_lower_name"
    remove_index :public_keys, :name, unique: true, name: "index_public_keys_on_name"
    add_index :public_keys, "lower(name)", unique: true, name: "index_public_keys_on_lower_name"
  end
end
