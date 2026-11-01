class ServersController < ApplicationController
  PER_PAGE = 100
  VIEWS = %w[list grid].freeze
  # Grid: the problems first.
  STATE_ORDER = { "crit" => 0, "off" => 0, "warn" => 1, "unknown" => 2, "ok" => 3 }.freeze
  HISTORY_PER_PAGE = 30

  require_permission :operate, only: %i[new create edit update destroy]

  before_action :set_server, only: %i[show edit update destroy]

  def index
    @groups = ServerGroup.order(:name)
    @group = @groups.find { |group| group.id.to_s == params[:group].to_s } if params[:group].present?
    @os_names = Server.where.not(os_name: nil).distinct.order(:os_name).pluck(:os_name)
    @os = params[:os].presence_in(@os_names)
    @state = params[:state].presence_in(Server::HEALTH_STATES + %w[off])
    @summary = FleetSummary.new(Server.includes(:inventory_snapshots))
    servers = (@group ? Server.in_group(@group) : Server.all).order(:name).includes(:server_groups, :inventory_snapshots)
    servers = servers.where(os_name: @os) if @os
    @q = params[:q].to_s.strip.first(100)
    servers = servers.to_a if @state || @q.present?
    servers = servers.select { |server| server.health_state == @state } if @state
    servers = servers.select { |server| server.matches_search?(@q) } if @q.present?
    @view = fleet_view
    servers = servers.to_a.sort_by { |server| [ STATE_ORDER.fetch(server.health_state, 2), server.name.downcase ] } if @view == "grid"
    @pager = paginate(servers, per_page: PER_PAGE)
    @servers = @pager.records
    @load_history = Inventory::HealthSample.where(server_id: @servers.map(&:id)).since(24.hours.ago)
                                           .pluck(:server_id, :load_percent).group_by(&:first).transform_values { |rows| rows.map(&:last).compact }
    @insights = KeyInsights.new
    if Integration.enabled?(:uptime_kuma)
      @monitor_counts = UptimeKumaMonitor.attached.group(:server_id).pluck(:server_id, Arel.sql("COUNT(*)"), Arel.sql("COUNT(*) FILTER (WHERE status = 0)"))
                                         .to_h { |server_id, total, down| [ server_id, [ total, down ] ] }
    end
  end

  TABS = %w[overview packages services schedules ports keys history].freeze

  # Tabbed page (?tab=), only the requested tab is rendered.
  def show
    @integration_tabs = Integration.server_tabs
    @tab = params[:tab].presence_in(TABS + @integration_tabs.map { |tab| tab[:key] }) || "overview"
    if @tab == "history"
      @pager = paginate(Activity.recent.where(server: @server).includes(:user, :server, :public_key), per_page: HISTORY_PER_PAGE)
      @activities = @pager.records
    end
    @health_history = @server.health_samples.since(24.hours.ago).pluck(:collected_at, :load_percent, :memory_percent, :disk_percent) if @tab == "overview"
  end

  def new
    @server = Server.new
  end

  def create
    @server = Server.new(server_params)

    if @server.save
      Activity.record!(:server_created, server: @server, address: "#{@server.username}@#{@server.host}:#{@server.port}")
      redirect_to server_path(@server), notice: "Le serveur « #{@server.name} » a été ajouté. Installez-y la clé d'Elio puis testez la connexion."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @server.update(server_params)
      changed = @server.saved_changes.keys & %w[name host port username]
      Activity.record!(:server_updated, server: @server, changed: changed) if changed.any?
      redirect_to server_path(@server), notice: "Le serveur « #{@server.name} » a été modifié."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  # Removes the server from Elio only: keys installed on the machine stay.
  def destroy
    active_temporary_accesses = @server.temporary_accesses.active.count
    @server.destroy!
    still_used = Server.exists?(host: @server.host, port: @server.port)
    Ssh::KnownHosts.forget(@server.host, @server.port) unless still_used
    Activity.record!(:server_deleted, server_name: @server.name, address: "#{@server.username}@#{@server.host}:#{@server.port}",
                                      active_temporary_accesses: active_temporary_accesses)

    redirect_to servers_path, notice: "Le serveur « #{@server.name} » a été supprimé d'Elio. Les clés installées dessus n'ont pas été retirées.",
                              status: :see_other
  end

  private

  # List (dense table) or grid (cards): ?view=, remembered in a cookie.
  def fleet_view
    view = params[:view].presence_in(VIEWS)
    cookies.permanent[:elio_fleet_view] = { value: view, same_site: :lax, httponly: true } if view
    view || cookies[:elio_fleet_view].presence_in(VIEWS) || "list"
  end

  def set_server
    @server = Server.find(params[:id])
  end

  def server_params
    params.expect(server: [ :name, :host, :port, :username, :extra_addresses_text, server_group_ids: [] ])
  end
end
