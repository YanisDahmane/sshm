class ServerAuthorizedKeysController < ApplicationController
  def index
    @server = Server.find(params[:server_id])
    @result = AuthorizedKeysReader.call(@server)
    @app_key = SshKey.current
    @profiles_by_fingerprint = Profile.where(fingerprint: @result.keys.map(&:fingerprint)).index_by(&:fingerprint)
    @authorizable_profiles = Profile.where.not(fingerprint: @profiles_by_fingerprint.keys).order(:name) if @result.success?
  end
end
