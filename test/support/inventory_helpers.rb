# Registers fake inventory collectors for the duration of a block.
module InventoryHelpers
  def with_collectors(registry)
    previous = Inventory::Collector.registry
    Inventory::Collector.registry = registry
    yield
  ensure
    Inventory::Collector.registry = previous
  end
end
