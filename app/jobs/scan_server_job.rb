class ScanServerJob < ApplicationJob
  queue_as :default

  discard_on ActiveJob::DeserializationError

  def perform(server)
    ServerScan.call(server)
  end
end
