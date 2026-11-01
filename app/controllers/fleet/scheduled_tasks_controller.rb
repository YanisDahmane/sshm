# Scheduled tasks of the whole fleet (Inventory::Collectors::ScheduledTasks):
# "which servers run backup.sh?" (?q= on the command, timer, unit, file),
# filters by group and state (?state=failed|late), problems first.
class ScheduledTasksController < ApplicationController
  PER_PAGE = 100
  STATES = %w[failed late].freeze
  Row = Data.define(:server, :kind, :name, :schedule, :command, :source, :user, :timer) do
    def failed? = timer&.dig("failed") == true
    def late? = timer&.dig("late") == true && !failed?
    def rank = failed? ? 0 : late? ? 1 : 2
  end

  def index
    @groups = ServerGroup.order(:name)
    @group = @groups.find { |group| group.id.to_s == params[:group].to_s } if params[:group].present?
    @q = params[:q].to_s.strip.first(100)
    @state = params[:state].presence_in(STATES)
    servers = (@group ? Server.in_group(@group) : Server.all).order(:name).includes(:inventory_snapshots).to_a
    @without_inventory = servers.reject { |server| server.inventory("scheduled_tasks")&.collected? }
    rows = servers.flat_map { |server| rows_for(server) }
    rows.select! { |row| row.public_send(:"#{@state}?") } if @state
    rows.select! { |row| matches?(row, @q) } if @q.present?
    @pager = paginate(rows.sort_by { |row| [ row.rank, row.server.name.downcase, row.kind, row.name.to_s ] }, per_page: PER_PAGE)
    @rows = @pager.records
  end

  private

  def rows_for(server)
    data = server.inventory("scheduled_tasks")&.data || {}
    Array(data["timers"]).map { |timer| Row.new(server, "timer", timer["name"], nil, timer["description"], timer["unit"], nil, timer) } +
      Array(data["cron"]).map { |task| Row.new(server, "cron", nil, task["schedule"], task["command"], task["source"], task["user"], nil) } +
      Array(data["periodic"]).map { |task| Row.new(server, "periodic", task["name"], task["period"], nil, "/etc/cron.#{task["period"]}", "root", nil) }
  end

  def matches?(row, query)
    needle = query.downcase
    [ row.name, row.command, row.source, row.user, row.timer&.dig("unit") ].compact.any? { |value| value.downcase.include?(needle) }
  end
end
