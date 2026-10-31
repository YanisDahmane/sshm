# Profiles become the keyring ("Trousseau"): public keys of team members or
# of servers, added to or removed from the servers.
class RenameProfilesToPublicKeys < ActiveRecord::Migration[8.1]
  RENAMED_KINDS = { "profile_created" => "public_key_created", "profile_deleted" => "public_key_deleted" }.freeze

  def up
    rename_table :profiles, :public_keys
    rename_column :public_keys, :public_key, :content
    add_column :public_keys, :kind, :string, null: false, default: "person"
    add_column :public_keys, :description, :text

    rename_column :activities, :profile_id, :public_key_id
    rename_column :temporary_accesses, :profile_id, :public_key_id

    RENAMED_KINDS.each do |from, to|
      execute "UPDATE activities SET kind = #{quote(to)} WHERE kind = #{quote(from)}"
      execute <<~SQL
        UPDATE notification_channels SET activity_kinds = (activity_kinds - #{quote(from)}) || #{quote([ to ].to_json)}::jsonb
        WHERE activity_kinds ? #{quote(from)}
      SQL
    end
    execute <<~SQL
      UPDATE activities SET data = (data - 'profile_name') || jsonb_build_object('public_key_name', data->'profile_name')
      WHERE data ? 'profile_name'
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end

  private

  def quote(value) = connection.quote(value)
end
