class ApplicationJob < ActiveJob::Base
  # Results and errors written by the jobs (tasks, last errors) are in the
  # instance's language, whoever started them. Notifications switch to their
  # channel's language.
  around_perform { |_job, block| I18n.with_locale(AppSetting.current.default_locale, &block) }
  # Automatically retry jobs that encountered a deadlock
  # retry_on ActiveRecord::Deadlocked

  # Most jobs are safe to ignore if the underlying records are no longer available
  # discard_on ActiveJob::DeserializationError
end
