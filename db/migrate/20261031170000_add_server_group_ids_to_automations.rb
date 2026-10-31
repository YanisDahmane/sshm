# Scope of an automation: some server groups, or the whole fleet when empty.
class AddServerGroupIdsToAutomations < ActiveRecord::Migration[8.1]
  def change
    add_column :automations, :server_group_ids, :jsonb, null: false, default: []
  end
end
