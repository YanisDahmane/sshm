# Collects the inventory of one server in the background (all categories, or
# the given ones).
class Inventory::CollectJob < ApplicationJob
  queue_as :default

  discard_on ActiveJob::DeserializationError

  def perform(server, categories = nil)
    Inventory::Collection.call(server, **{ categories: categories }.compact)
  end
end
