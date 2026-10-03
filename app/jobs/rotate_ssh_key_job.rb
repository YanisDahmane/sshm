# Rotates SSHM's key on every server (see KeyRotation), through the account
# SSHM logs in as: install the new key with the old one, check a login with
# the new key, remove the old key with the new one. retry_failed only redoes
# the failed servers.
class RotateSshKeyJob < ApplicationJob
  class StepFailed < StandardError
    attr_reader :phase

    def initialize(phase, message)
      @phase = phase
      super(message)
    end
  end

  queue_as :default

  discard_on ActiveJob::DeserializationError

  def perform(rotation, retry_failed: false)
    Current.user = rotation.started_by
    servers = if retry_failed
      failed = rotation.steps.failed.includes(:server).to_a
      rotation.update!(finished_at: nil)
      KeyRotationStep.where(id: failed.map(&:id)).delete_all
      failed.filter_map(&:server)
    else
      Server.order(:name).to_a
    end

    servers.each { |server| rotate(rotation, server) }
    rotation.finish!
  ensure
    Current.reset
  end

  private

  def rotate(rotation, server)
    account = AuthorizedKeysAccount.login(server)
    install(rotation, server, account)
    verify(rotation, server)
    cleanup(rotation, server, account)
    rotation.steps.create!(server: server, server_name: server.name, status: :rotated)
  rescue StepFailed => e
    rotation.steps.create!(server: server, server_name: server.name, status: :failed, phase: e.phase, error_message: e.message)
  end

  def install(rotation, server, account)
    new_key = rotation.new_key
    script = ProfileAuthorization.append_script(new_key.public_key, new_key.blob, home: account.home)
    SshConnection.open(server, key: [ rotation.old_key, new_key ]) { |ssh| ssh.exec!(account.command(script)) }
  rescue SshConnection::Error => e
    raise StepFailed.new("install", "#{e.title} — #{e.message}")
  end

  def verify(rotation, server)
    check = SshCheck.call(server, key: rotation.new_key)
    raise StepFailed.new("verify", "#{check.message} — #{check.details}") unless check.success?
  end

  def cleanup(rotation, server, account)
    return unless rotation.old_key

    removal = AuthorizedKeyRemoval.call(server, rotation.old_key.blob, account: account, protected_keys: [ rotation.new_key ], key: rotation.new_key)
    raise StepFailed.new("cleanup", "#{removal.error_title} — #{removal.error_details}") unless removal.success?
  end
end
