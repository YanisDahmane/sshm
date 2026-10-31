# For the jobs that work on one item of a BackgroundTask: the item is running
# during the job, and failed if the job crashes (the error is re-raised).
module TracksTaskItem
  extend ActiveSupport::Concern

  private

  def tracking(item)
    item&.start!
    yield
  rescue StandardError => e
    item&.finish!(:failed, "Erreur interne (#{e.class})") unless item&.reload&.finished?
    raise
  end
end
