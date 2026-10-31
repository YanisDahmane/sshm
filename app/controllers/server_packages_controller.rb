# Packages of a server (lazy frame of the server page), searchable and
# filterable: ?q=, ?manager=, ?updates=1 (only the upgradable ones).
class ServerPackagesController < ApplicationController
  LIMIT = 200

  def index
    @server = Server.find(params[:server_id])
    @snapshot = @server.inventory("packages")
    @q = params[:q].to_s.strip.first(100)
    @manager = params[:manager].presence_in(Inventory::Package::MANAGERS.keys)
    @updates = params[:updates] == "1"

    packages = @server.packages.order(:name, :arch)
    packages = packages.search(@q) if @q.present?
    packages = packages.where(manager: @manager) if @manager
    packages = packages.upgradable.reorder(security: :desc, name: :asc) if @updates
    @count = packages.count
    @packages = packages.limit(LIMIT)
  end
end
