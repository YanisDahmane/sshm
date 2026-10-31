# Collects the inventory of one server in the background (all categories, or
# the given ones), reporting to its BackgroundTask item when there is one.
class Inventory::CollectJob < ApplicationJob
  include TracksTaskItem

  queue_as :default

  discard_on ActiveJob::DeserializationError

  def perform(server, categories = nil, task_item: nil)
    tracking(task_item) do
      outcomes = Inventory::Collection.call(server, **{ categories: categories }.compact)
      task_item&.finish_inventory!(outcomes)
    end
  end
end
