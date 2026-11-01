# Starts an inventory collection in the background, on one server
# (POST /servers/:server_id/inventory) or on every server (POST /servers/inventory),
# followed as a task on the "Tâches" page.
class ServerInventoriesController < ApplicationController
  require_permission :operate

  def create
    servers = params[:server_id] ? [ Server.find(params[:server_id]) ] : Server.order(:name).to_a
    label = params[:server_id] ? t("server_inventories_controller.label_one", first_name: servers.first.name) : t("server_inventories_controller.label_fleet", t: (helpers.t("count.servers", count: servers.size)))
    task = BackgroundTask.enqueue!(kind: "inventory", label: label, servers: servers) do |item|
      Inventory::CollectJob.perform_later(item.server, task_item: item)
    end

    redirect_to task_path(task), notice: t("server_inventories_controller.started", label: label)
  end
end
