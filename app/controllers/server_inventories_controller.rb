# Starts an inventory collection in the background, on one server
# (POST /servers/:server_id/inventory) or on every server (POST /servers/inventory).
class ServerInventoriesController < ApplicationController
  require_permission :operate

  def create
    servers = params[:server_id] ? [ Server.find(params[:server_id]) ] : Server.order(:name).to_a
    servers.each { |server| Inventory::CollectJob.perform_later(server) }

    notice = if params[:server_id]
      "Inventaire de « #{servers.first.name} » lancé. Actualisez la page dans quelques instants."
    else
      "Inventaire lancé sur #{helpers.pluralize_fr(servers.size, "serveur", "serveurs")}. Actualisez la page dans quelques instants."
    end
    redirect_back_or_to(params[:server_id] ? server_path(servers.first) : servers_path, notice: notice)
  end
end
