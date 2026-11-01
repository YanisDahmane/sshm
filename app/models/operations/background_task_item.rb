# One server of a BackgroundTask: queued → running → succeeded / partial / failed.
class BackgroundTaskItem < ApplicationRecord
  belongs_to :task, class_name: "BackgroundTask", foreign_key: :background_task_id, inverse_of: :items
  belongs_to :server, optional: true

  validates :status, inclusion: { in: BackgroundTask::STATUSES }

  scope :unfinished, -> { where(status: %w[queued running]) }

  def finished? = BackgroundTask::FINISHED.include?(status)

  def start!
    update!(status: "running", started_at: Time.current)
    task.start!
  end

  def finish!(status, message = nil, details: {})
    update!(status: status.to_s, message: message, details: details, finished_at: Time.current, started_at: started_at || Time.current)
    task.refresh!
  end

  # Inventory::Collection outcomes ({ category => Outcome }): failed if every
  # category failed, partial if some did or were collected partially.
  def finish_inventory!(outcomes)
    statuses = outcomes.values.map(&:status)
    status = if statuses.any? && statuses.all?("error") then :failed
    elsif statuses.any? { |value| %w[error partial].include?(value) } then :partial
    else :succeeded
    end
    problems = outcomes.reject { |_, outcome| %w[ok unsupported].include?(outcome.status) }
    messages = problems.values.map(&:message).uniq
    # The same error everywhere (connection impossible): said once.
    message = if problems.size == outcomes.size && problems.size > 1 && messages.one? then messages.first
    else problems.map { |category, outcome| "#{Inventory::Collector.label_for(category)} : #{outcome.message}" }.join(" · ").presence
    end
    finish!(status, message, details: outcomes.transform_values { |outcome| { "status" => outcome.status, "message" => outcome.message }.compact })
  end

  # The server is deleted while its item waits (the job will be discarded).
  def self.cancel_for_server!(server)
    where(server: server).unfinished.includes(:task).find_each { |item| item.finish!(:failed, I18n.t("background_task_item.server_deleted")) }
  end

  def duration = started_at && finished_at && finished_at - started_at
end
