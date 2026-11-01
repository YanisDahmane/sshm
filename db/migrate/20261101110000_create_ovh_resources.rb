class CreateOvhResources < ActiveRecord::Migration[8.1]
  def change
    # OVHcloud resources read by the extension (IP blocks, DNS records,
    # dedicated servers, VPS, Public Cloud instances), replaced at each sync.
    create_table :ovh_resources do |t|
      t.string :kind, null: false
      t.string :external_id, null: false
      t.string :name, null: false
      t.jsonb :data, null: false, default: {}
      t.jsonb :addresses, null: false, default: []
      t.date :expires_at
      t.references :server, foreign_key: { on_delete: :nullify }
      t.string :matched_by # address, service, name, cname, manual
      t.string :matched_address
      t.timestamps
    end
    add_index :ovh_resources, %i[kind external_id], unique: true
  end
end
