# "Tâches": the background tasks (inventories, keys scans, automation runs)
# with their status, and what is coming (queued tasks, next automations).
# Visible to every role; the queue's technical view is /jobs (admins).
class TasksController < ApplicationController
  PER_PAGE = 50

  def index
    @filter = params[:status].presence_in(BackgroundTask::FILTERS.keys)
    @pager = paginate(BackgroundTask.filtered(@filter).recent.includes(:user), per_page: PER_PAGE)
    @tasks = @pager.records
    @counts = BackgroundTask.group(:status).count
    @upcoming_automations = Automation.where(enabled: true).to_a.sort_by(&:next_run_at)
    @workers_running = JobWorkers.running?
  end

  def show
    @task = BackgroundTask.find(params[:id])
    @items = @task.items.includes(:server)
    @workers_running = JobWorkers.running? if @task.unfinished?
  end
end
