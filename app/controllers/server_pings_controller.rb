class ServerPingsController < ApplicationController
  include ActionView::RecordIdentifier

  def create
    if params[:server_id]
      server = Server.find(params[:server_id])
      reachable = ServerPing.check!(server)
      servers = [ server ]
      notice = "« #{server.name} » est #{reachable ? "en ligne" : "injoignable"}."
    else
      results = ServerPing.check_all!(Server.all)
      servers = results.keys
      notice = "Statuts actualisés : #{results.values.count(true)} en ligne, #{results.values.count(false)} injoignable(s)."
    end

    respond_to do |format|
      format.turbo_stream do
        flash.now[:notice] = notice
        render turbo_stream: [
          *servers.map { |server| turbo_stream.replace(dom_id(server, :status), partial: "servers/status", locals: { server: server }) },
          turbo_stream.update("flash", partial: "shared/flash")
        ]
      end
      format.html { redirect_back_or_to root_path, notice: notice }
    end
  end
end
