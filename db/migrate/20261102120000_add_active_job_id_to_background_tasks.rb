# The Active Job id of the job running a task (an automation, an import) or
# one of its items (one job per server), to tell a task whose job no longer
# exists (StaleTasks).
class AddActiveJobIdToBackgroundTasks < ActiveRecord::Migration[8.1]
  def change
    add_column :background_tasks, :active_job_id, :string
    add_column :background_task_items, :active_job_id, :string
  end
end
