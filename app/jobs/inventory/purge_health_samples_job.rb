# Deletes the health history older than Inventory::HealthSample::RETENTION (daily).
class Inventory::PurgeHealthSamplesJob < ApplicationJob
  queue_as :default

  def perform = Inventory::HealthSample.purge!
end
