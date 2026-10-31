# Reads the authorized keys of one server, reporting to its BackgroundTask
# item when there is one.
class ScanServerJob < ApplicationJob
  include TracksTaskItem

  queue_as :default

  discard_on ActiveJob::DeserializationError

  def perform(server, task_item: nil)
    tracking(task_item) do
      scan = ServerScan.call(server)
      task_item&.finish!(scan.success? ? :succeeded : :failed, scan.error_title)
    end
  end
end
