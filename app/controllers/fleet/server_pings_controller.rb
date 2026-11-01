class ServerPingsController < ApplicationController
  include ActionView::RecordIdentifier

  # Pings one server and renders its reachability frame (server page, loaded
  # on display and on refresh).
  def show
    @server = Server.find(params[:server_id])
    Servers::Ping.check!(@server)
  end

  def create
    if params[:server_id]
      server = Server.find(params[:server_id])
      reachable = Servers::Ping.check!(server)
      servers = [ server ]
      notice = t(reachable ? "server_pings_controller.online" : "server_pings_controller.unreachable", server_name: server.name)
    else
      results = Servers::Ping.check_all!(Server.all)
      servers = results.keys
      notice = t("server_pings_controller.refreshed", online: results.values.count(true), unreachable: results.values.count(false))
    end

    respond_to do |format|
      format.turbo_stream do
        flash.now[:notice] = notice
        render turbo_stream: [
          *servers.map { |server| turbo_stream.replace(dom_id(server, :status), partial: "servers/status", locals: { server: server, health: params[:badge] == "health" }) },
          turbo_stream.update("flash", partial: "shared/flash")
        ]
      end
      format.html { redirect_back_or_to root_path, notice: notice }
    end
  end
end
