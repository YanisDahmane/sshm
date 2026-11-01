# Tasks left "queued" or "running" by a job that no longer exists — the
# worker was killed, the queue database was reset, the job failed for good —
# are finished after AFTER: their unfinished items fail with "Interrupted",
# then the task's status is computed again. A task whose job still waits in
# Solid Queue or is held by a live worker is never touched.
#
# SweepStaleTasksJob runs it every 15 minutes (with Solid Queue only).
module StaleTasks
  AFTER = 3.hours

  # Returns the number of tasks finished.
  def self.call(now: Time.current)
    tasks = BackgroundTask.unfinished.where(created_at: ..(now - AFTER)).includes(:items).to_a
    return 0 if tasks.empty?

    job_ids = tasks.flat_map { |task| [ task.active_job_id, *task.items.map(&:active_job_id) ] }.compact
    live = live_job_ids(job_ids)
    tasks.count { |task| sweep(task, live, now) }
  end

  # A task run by one job (automation, import, extension) is interrupted when
  # its job is gone; a task with one job per server item, item by item.
  def self.sweep(task, live, now)
    return false if task.active_job_id && live.include?(task.active_job_id)
    return task.fail!(message).then { true } if task.active_job_id || task.items.none?

    dead = task.items.select { |item| item.status.in?(%w[queued running]) && !live.include?(item.active_job_id) }
    return false if dead.empty?

    BackgroundTaskItem.where(id: dead).update_all(status: "failed", message: message, finished_at: now, updated_at: now)
    task.refresh!
    true
  end

  def self.message = I18n.t("background_task.orphaned")

  # Active Job ids of the jobs still alive in Solid Queue: waiting (ready,
  # scheduled, blocked) or claimed by a process that still beats.
  def self.live_job_ids(active_job_ids)
    return [] if active_job_ids.empty?

    jobs = SolidQueue::Job.where(active_job_id: active_job_ids, finished_at: nil).pluck(:id, :active_job_id).to_h
    waiting = [ SolidQueue::ReadyExecution, SolidQueue::ScheduledExecution, SolidQueue::BlockedExecution ].flat_map { |model| model.where(job_id: jobs.keys).pluck(:job_id) }
    alive = SolidQueue::Process.where(last_heartbeat_at: SolidQueue.process_alive_threshold.ago..).select(:id)
    claimed = SolidQueue::ClaimedExecution.where(job_id: jobs.keys, process_id: alive).pluck(:job_id)
    (waiting + claimed).map { |id| jobs[id] }
  end
end
