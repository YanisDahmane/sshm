class DashboardController < ApplicationController
  def index
    @servers = Server.order(:name)
    @profiles = Profile.order(:name)
    @ssh_key_configured = SshKey.exists?
  end
end
