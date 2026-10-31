# Optional list of the ports a group's servers are expected to expose
# (e.g. "22, 80, 443/tcp"): other public ports are flagged as unexpected.
class AddExpectedPortsToServerGroups < ActiveRecord::Migration[8.1]
  def change
    add_column :server_groups, :expected_ports, :string
  end
end
