# Is a Solid Queue worker running? Without one, the tasks stay "à venir"
# forever (what happened in development before Solid Queue ran in Puma).
# nil when it cannot be known (another queue adapter, queue database absent).
module JobWorkers
  HEARTBEAT = 5.minutes

  def self.running?
    return unless ActiveJob::Base.queue_adapter.is_a?(ActiveJob::QueueAdapters::SolidQueueAdapter)

    SolidQueue::Process.where(kind: "Worker").where(last_heartbeat_at: HEARTBEAT.ago..).exists?
  rescue ActiveRecord::ActiveRecordError
    nil
  end
end
