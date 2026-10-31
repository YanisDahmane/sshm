# Public ports of the whole fleet (Inventory::PortAnalysis of each server),
# filterable by group and port (?group=, ?q= — not ?port=, a URL option of Rails), unexpected ones first.
class PortsController < ApplicationController
  PER_PAGE = 100

  def index
    @groups = ServerGroup.order(:name)
    @group = @groups.find { |group| group.id.to_s == params[:group].to_s } if params[:group].present?
    @port = params[:q].to_s[/\d+/]&.to_i
    servers = (@group ? Server.in_group(@group) : Server.all).order(:name).includes(:inventory_snapshots, :server_groups)
    @analyses = servers.map { |server| Inventory::PortAnalysis.new(server) }
    @rows = @analyses.flat_map { |analysis| analysis.public_ports.map { |port| [ analysis.server, port ] } }
    @rows.select! { |_, port| port.port == @port } if @port
    @rows.sort_by! { |server, port| [ port.unexpected ? 0 : 1, %w[open docker].include?(port.firewall) ? 0 : 1, port.port, server.name ] }
    @without_inventory = @analyses.reject(&:collected?).map(&:server)
    @pager = paginate(@rows, per_page: PER_PAGE)
    @rows = @pager.records
  end
end
