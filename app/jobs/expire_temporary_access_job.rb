# Removes the authorized_keys line of an expired TemporaryAccess and ends it.
# Retried while the server cannot be reached (sshd already refuses the key
# thanks to its expiry-time option).
class ExpireTemporaryAccessJob < ApplicationJob
  class RemovalFailed < StandardError; end

  queue_as :default

  retry_on RemovalFailed, wait: 1.minute, attempts: 60
  discard_on ActiveJob::DeserializationError

  def perform(access)
    return unless access.active?
    return self.class.set(wait_until: access.expires_at).perform_later(access) unless access.expired?

    result = AuthorizedKeyRemoval.call(access.server, access.key_blob, account: access.account)
    raise RemovalFailed, "#{result.error_title}: #{result.error_details}" unless result.success?

    access.end!
  end
end
