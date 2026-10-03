class ServersController < ApplicationController
  before_action :set_server, only: %i[show edit update]

  def index
    @servers = Server.order(:name)
    @insights = KeyInsights.new
  end

  def show
    @activities = Activity.recent.where(server: @server).includes(:user, :server, :profile).limit(10)
  end

  def new
    @server = Server.new
  end

  def create
    @server = Server.new(server_params)

    if @server.save
      Activity.record!(:server_created, server: @server, address: "#{@server.username}@#{@server.host}:#{@server.port}")
      redirect_to server_path(@server), notice: "Le serveur « #{@server.name} » a été ajouté. Installez-y la clé de SSHM puis testez la connexion."
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

  private

  def set_server
    @server = Server.find(params[:id])
  end

  def server_params
    params.expect(server: [ :name, :host, :port, :username ])
  end
end
