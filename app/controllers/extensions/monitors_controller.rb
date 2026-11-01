# "Sondes" (Uptime Kuma extension): every probe with its server, the probes
# attached to no server, the servers watched by no probe.
class MonitorsController < ApplicationController
  include RequiresIntegration

  PER_PAGE = 100
  FILTERS = %w[unattached down without].freeze

  requires_integration :uptime_kuma

  def index
    @filter = params[:filter].presence_in(FILTERS)
    @q = params[:q].to_s.strip.first(100)
    monitors = UptimeKumaMonitor.includes(server: :inventory_snapshots).by_name
    @counts = { total: UptimeKumaMonitor.count, unattached: UptimeKumaMonitor.unattached.count, down: UptimeKumaMonitor.where(status: 0).count }
    @servers_without = Server.where.not(id: UptimeKumaMonitor.attached.select(:server_id)).order(:name).includes(:server_groups)

    if @filter == "without"
      @pager = paginate(@servers_without, per_page: PER_PAGE)
    else
      monitors = monitors.unattached if @filter == "unattached"
      monitors = monitors.where(status: 0) if @filter == "down"
      monitors = monitors.where("uptime_kuma_monitors.name ILIKE :q OR uptime_kuma_monitors.hostname ILIKE :q OR uptime_kuma_monitors.url ILIKE :q",
                                q: "%#{UptimeKumaMonitor.sanitize_sql_like(@q)}%") if @q.present?
      @pager = paginate(monitors, per_page: PER_PAGE)
    end
  end
end
