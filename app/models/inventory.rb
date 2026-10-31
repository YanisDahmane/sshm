# Everything Elio collects about a server over SSH (system, health, packages,
# services, ports): models, collectors and jobs live in this namespace.
module Inventory
  def self.table_name_prefix = "inventory_"
end
