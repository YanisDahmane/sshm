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

  private

  # The last ping result no longer applies once the address changes.
  def reset_reachability
    self.reachable = nil
    self.last_checked_at = nil
  end

  def host_must_be_an_ip_or_hostname
    return if host.blank?
    return if host.match?(Resolv::IPv4::Regex) || host.match?(Resolv::IPv6::Regex) || host.match?(HOSTNAME_REGEXP)

    errors.add(:host, :invalid)
  end
end
