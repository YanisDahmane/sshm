require "resolv"

class Server < ApplicationRecord
  has_many :account_snapshots, dependent: :delete_all
  has_many :temporary_accesses, dependent: :delete_all
  has_many :activities, dependent: :nullify
  has_many :server_group_memberships, dependent: :delete_all
  has_many :server_groups, -> { order(:name) }, through: :server_group_memberships
  has_many :inventory_snapshots, class_name: "Inventory::Snapshot", dependent: :delete_all
  has_many :health_samples, class_name: "Inventory::HealthSample", dependent: :delete_all
  has_many :packages, class_name: "Inventory::Package", dependent: :delete_all
  # Tasks keep the server's name; a server deleted while waiting fails its items.
  has_many :background_task_items, dependent: :nullify
  before_destroy(prepend: true) { BackgroundTaskItem.cancel_for_server!(self) }

  HEALTH_STATES = %w[ok warn crit unknown].freeze

  # How root commands run on the server (see Ssh::Connection#privilege), as
  # found by the last inventory: root, sudo or none.
  PRIVILEGES = %w[root sudo none].freeze
  validates :privilege, inclusion: { in: PRIVILEGES }, allow_nil: true

  scope :in_group, ->(group) { where(id: ServerGroupMembership.where(server_group: group).select(:server_id)) }
  HOSTNAME_REGEXP = /\A(?=.{1,253}\z)([a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?)(\.[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?)*\z/i

  normalizes :name, :host, :username, with: ->(value) { value.strip }

  validates :name, presence: true, uniqueness: { case_sensitive: false }
  validates :host, presence: true
  validates :port, numericality: { only_integer: true, in: 1..65_535 }
  validates :username, presence: true
  validate :host_must_be_an_ip_or_hostname

  before_update :reset_reachability, if: -> { will_save_change_to_host? || will_save_change_to_port? }

  # Remembers whether the app could log in over SSH (see Ssh::Check); `nil` = unknown.
  # Logs ssh_access_lost when a server that accepted the Elio key refuses it.
  def record_ssh_status!(ok)
    lost = ssh_ok == true && ok == false
    changed = ssh_ok != ok
    update_columns(ssh_ok: ok, ssh_checked_at: Time.current)
    Activity.record!(:ssh_access_lost, server: self) if lost
    refresh_health! if changed && health_status.present?
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

  def inventory(category) = inventory_snapshots.find { |snapshot| snapshot.category == category.to_s }

  # Health shown in the interface: "off" when the last ping failed, otherwise
  # the state computed from the inventory (ok, warn, crit, unknown).
  def health_state = reachable == false ? "off" : (health_status || "unknown")

  # Main reasons of the health state, most serious first.
  def health_reason_texts = Array(health_reasons).map { |reason| reason["text"] }

  # Recomputes the health state (Inventory::HealthStatus) and logs when it
  # changes between ok, warn and crit (not on the first evaluation).
  def refresh_health!
    previous = health_status
    inventory_snapshots.reset
    result = Inventory::HealthStatus.evaluate(self)
    update_columns(health_status: result.state, health_reasons: result.reasons.map(&:to_h))
    return if previous.nil? || previous == "unknown" || result.state == "unknown" || previous == result.state

    kind = { "ok" => :health_recovered, "warn" => :health_warning, "crit" => :health_critical }.fetch(result.state)
    Activity.record!(kind, server: self, user: nil, reasons: result.reasons.map(&:text).first(3))
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
