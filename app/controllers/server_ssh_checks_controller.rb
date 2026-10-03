class ServerSshChecksController < ApplicationController
  # Checks SSH access to a server and renders its SSH frame (server page,
  # loaded on display and on refresh).
  def show
    @server = Server.find(params[:server_id])
    @result = SshCheck.call(@server)
    @server.record_ssh_status!(@result.success?) unless @result.reason == :missing_key
  end
end
