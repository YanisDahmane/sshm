class DashboardController < ApplicationController
  def index
    @servers = Server.order(:name)
    @ssh_key_configured = SshKey.exists?
  end
end
