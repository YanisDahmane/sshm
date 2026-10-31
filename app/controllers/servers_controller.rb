class ServersController < ApplicationController
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
    @servers = @state ? servers.select { |server| server.health_state == @state } : servers.to_a
    @load_history = Inventory::HealthSample.where(server_id: @servers.map(&:id)).since(24.hours.ago)
                                           .pluck(:server_id, :load_percent).group_by(&:first).transform_values { |rows| rows.map(&:last).compact }
    @insights = KeyInsights.new
  end

  def show
    @activities = Activity.recent.where(server: @server).includes(:user, :server, :public_key).limit(10)
    @health_history = @server.health_samples.since(24.hours.ago).pluck(:collected_at, :load_percent, :memory_percent, :disk_percent)
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
    KnownHosts.forget(@server.host, @server.port) unless still_used
    Activity.record!(:server_deleted, server_name: @server.name, address: "#{@server.username}@#{@server.host}:#{@server.port}",
                                      active_temporary_accesses: active_temporary_accesses)

    redirect_to servers_path, notice: "Le serveur « #{@server.name} » a été supprimé d'Elio. Les clés installées dessus n'ont pas été retirées.",
                              status: :see_other
  end

  private

  def set_server
    @server = Server.find(params[:id])
  end

  def server_params
    params.expect(server: [ :name, :host, :port, :username, server_group_ids: [] ])
  end
end
