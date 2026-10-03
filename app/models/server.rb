require "resolv"

class Server < ApplicationRecord
  HOSTNAME_REGEXP = /\A(?=.{1,253}\z)([a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?)(\.[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?)*\z/i

  normalizes :name, :host, :username, with: ->(value) { value.strip }

  validates :name, presence: true, uniqueness: { case_sensitive: false }
  validates :host, presence: true
  validates :port, numericality: { only_integer: true, in: 1..65_535 }
  validates :username, presence: true
  validate :host_must_be_an_ip_or_hostname

  before_update :reset_reachability, if: -> { will_save_change_to_host? || will_save_change_to_port? }

  # Remembers whether the app could log in over SSH (see SshCheck); `nil` = unknown.
  # Logs ssh_access_lost when a server that accepted the SSHM key refuses it.
  def record_ssh_status!(ok)
    lost = ssh_ok == true && ok == false
    update_columns(ssh_ok: ok, ssh_checked_at: Time.current)
    Activity.record!(:ssh_access_lost, server: self) if lost
  end

  # Remembers a ping result (see ServerPing) and logs when the server goes
  # down (server_unreachable) or comes back (server_back_online).
  def record_reachability!(reachable)
    previous = self.reachable
    update_columns(reachable: reachable, last_checked_at: Time.current)
    if !reachable && previous != false
      Activity.record!(:server_unreachable, server: self)
    elsif reachable && previous == false
      Activity.record!(:server_back_online, server: self)
    end
  end

  private

  # The last ping and SSH results no longer apply once the address changes.
  def reset_reachability
    self.reachable = nil
    self.last_checked_at = nil
    self.ssh_ok = nil
    self.ssh_checked_at = nil
  end

  def host_must_be_an_ip_or_hostname
    return if host.blank?
    return if host.match?(Resolv::IPv4::Regex) || host.match?(Resolv::IPv6::Regex) || host.match?(HOSTNAME_REGEXP)

    errors.add(:host, :invalid)
  end
end
