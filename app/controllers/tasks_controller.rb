# "Tâches": the background tasks (inventories, keys scans, automation runs)
# with their status, and what is coming (queued tasks, next automations).
# Visible to every role; the queue's technical view is /jobs (admins).
class TasksController < ApplicationController
  PER_PAGE = 50

  def index
    @filter = params[:status].presence_in(BackgroundTask::FILTERS.keys)
    @page = [ params[:page].to_i, 1 ].max
    tasks = BackgroundTask.filtered(@filter).recent.includes(:user).offset((@page - 1) * PER_PAGE).limit(PER_PAGE + 1).to_a
    @more = tasks.size > PER_PAGE
    @tasks = tasks.first(PER_PAGE)
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
