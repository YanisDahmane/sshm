class CreateImageUpdates < ActiveRecord::Migration[8.1]
  def change
    # Digest of each image tag at its registry (ImageRegistry::UpdateCheck), compared with the pulled one.
    create_table :image_updates do |t|
      t.string :reference, null: false, index: { unique: true }
      t.string :registry, null: false
      t.string :repository, null: false
      t.string :tag, null: false
      t.string :remote_digest
      t.datetime :checked_at
      t.string :error
    end

    change_table :app_settings, bulk: true do |t|
      t.boolean :docker_alert_unhealthy, null: false, default: true
      t.boolean :docker_alert_restarts, null: false, default: true
      t.boolean :docker_alert_updates, null: false, default: false
      t.text :docker_registry_credentials
    end
  end
end
