class ServerScansController < ApplicationController
  # Reads the keys of every account of every server in the background.
  def create
    servers = Server.all.to_a
    servers.each { |server| ScanServerJob.perform_later(server) }

    redirect_back_or_to servers_path, notice: "Scan des clés lancé sur #{helpers.pluralize(servers.size, "serveur", plural: "serveurs")}. Actualisez la page dans quelques instants."
  end
end
