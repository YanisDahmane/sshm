# Safety net run every minute (config/recurring.yml): expires the temporary
# accesses whose scheduled job was lost.
class ExpireTemporaryAccessesJob < ApplicationJob
  queue_as :default

  def perform
    TemporaryAccess.expired.find_each { |access| ExpireTemporaryAccessJob.perform_later(access) }
  end
end
