class ServersController < ApplicationController
  before_action :set_server, only: %i[show edit update]

  def show
  end

  def new
    @server = Server.new
  end

  def create
    @server = Server.new(server_params)

    if @server.save
      redirect_to root_path, notice: "Le serveur « #{@server.name} » a été ajouté."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @server.update(server_params)
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
