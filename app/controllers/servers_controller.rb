class ServersController < ApplicationController
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

  private

  def server_params
    params.expect(server: [ :name, :host, :port, :username, :password ])
  end
end
