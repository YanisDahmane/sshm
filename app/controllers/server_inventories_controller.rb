# Starts an inventory collection in the background, on one server
# (POST /servers/:server_id/inventory) or on every server (POST /servers/inventory),
# followed as a task on the "Tâches" page.
class ServerInventoriesController < ApplicationController
  require_permission :operate

  def create
    servers = params[:server_id] ? [ Server.find(params[:server_id]) ] : Server.order(:name).to_a
    label = params[:server_id] ? "Inventaire de « #{servers.first.name} »" : "Inventaire du parc (#{helpers.pluralize_fr(servers.size, "serveur", "serveurs")})"
    task = BackgroundTask.enqueue!(kind: "inventory", label: label, servers: servers) do |item|
      Inventory::CollectJob.perform_later(item.server, task_item: item)
    end

    redirect_to task_path(task), notice: "#{label} lancé."
  end
end
