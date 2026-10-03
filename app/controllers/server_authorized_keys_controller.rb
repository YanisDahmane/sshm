class ServerAuthorizedKeysController < ApplicationController
  def index
    @server = Server.find(params[:server_id])
    @result = AuthorizedKeysReader.call(@server)
    @app_key = SshKey.current
  end
end
