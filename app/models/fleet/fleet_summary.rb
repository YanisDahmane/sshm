# Figures of the fleet shown above the server list (and on the overview):
# servers online, to watch, critical (unreachable included), pending security
# updates. Servers must come with their inventory snapshots loaded.
class FleetSummary
  attr_reader :servers

  def initialize(servers)
    @servers = servers.to_a
  end

  def total = servers.size

  def online = servers.count { |server| server.reachable }

  def to_watch = servers.count { |server| server.health_state == "warn" }

  def critical = servers.count { |server| %w[crit off].include?(server.health_state) }

  def unreachable = servers.count { |server| server.health_state == "off" }

  def security_updates = updates.sum { |counts| counts["security"].to_i }

  def servers_with_security_updates = updates.count { |counts| counts["security"].to_i.positive? }

  def last_inventory_at = servers.filter_map(&:inventoried_at).max

  private

  def updates = @updates ||= servers.filter_map { |server| server.inventory("health")&.data&.dig("updates") }
end
