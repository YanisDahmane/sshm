# Removes a profile's key from every discovered account of every server, step
# by step (see Revocation). With retry_failed, only redoes what failed: the
# failed accounts, or whole servers whose accounts could not be listed.
class RevokeProfileEverywhereJob < ApplicationJob
  queue_as :default

  discard_on ActiveJob::DeserializationError

  def perform(revocation, retry_failed: false)
    Current.user = revocation.started_by # removals are logged as theirs

    if retry_failed
      retry_failed_steps(revocation)
    else
      Server.order(:name).each { |server| revoke_on_server(revocation, server) }
    end

    revocation.finish!
  ensure
    Current.reset
  end

  private

  def retry_failed_steps(revocation)
    failed = revocation.steps.failed.includes(:server).to_a
    revocation.update!(finished_at: nil)
    RevocationStep.where(id: failed.map(&:id)).delete_all

    failed.group_by(&:server).each do |server, steps|
      next unless server

      accounts = steps.any?(&:server_level?) ? nil : steps.map { |step| AuthorizedKeysAccount.for(server, step.unix_user) }
      revoke_on_server(revocation, server, accounts: accounts)
    end
  end

  def revoke_on_server(revocation, server, accounts: nil)
    accounts ||= discover_accounts(revocation, server)
    return unless accounts

    accounts.each do |account|
      result = KeyRevocation.call(server, revocation.key_blob, account: account, key_name: revocation.profile_name, profile: revocation.profile)
      revocation.steps.create!(server: server, server_name: server.name, unix_user: account.unix_user,
                               status: result.success? ? result.status : :failed,
                               error_message: result.success? ? nil : "#{result.error_title} — #{result.error_details}")
    end
  end

  def discover_accounts(revocation, server)
    discovery = ServerAccountsReader.call(server)
    return discovery.accounts if discovery.success?

    revocation.steps.create!(server: server, server_name: server.name, status: :failed,
                             error_message: "#{discovery.error_title} — #{discovery.error_details}")
    nil
  end
end
