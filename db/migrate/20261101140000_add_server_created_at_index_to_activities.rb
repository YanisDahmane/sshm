# The history of a server lists its activities, most recent first, page by
# page: one index serves the filter and the order (AUDIT.md D12).
class AddServerCreatedAtIndexToActivities < ActiveRecord::Migration[8.1]
  def change
    add_index :activities, %i[server_id created_at]
    remove_index :activities, :server_id
  end
end
