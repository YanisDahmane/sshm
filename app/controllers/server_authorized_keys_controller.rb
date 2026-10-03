class ServerAuthorizedKeysController < ApplicationController
  include AuthorizedKeysRefresh

  before_action :set_server_and_account

  def index
    @result = AuthorizedKeysReader.call(@server, account: @account)
    @accounts = @result.success? ? ServerAccountsReader.call(@server).accounts : [ @account ]
    @accounts |= [ @account ]
    @app_key = SshKey.current
    @profiles_by_fingerprint = Profile.where(fingerprint: @result.keys.map(&:fingerprint)).index_by(&:fingerprint)
    @authorizable_profiles = Profile.where.not(fingerprint: @profiles_by_fingerprint.keys).order(:name) if @result.success?
  end

  # Removes the key whose base64 blob is params[:key] from the account's file.
  def destroy
    name = params[:name].presence || "sans nom"
    result = AuthorizedKeyRemoval.call(@server, params.expect(:key), account: @account)
    target = "« #{@server.name} » pour #{@account.unix_user}"

    flash_type, message = if result.removed?
      [ :notice, "La clé « #{name} » a été supprimée de #{target}." ]
    elsif result.absent?
      [ :notice, "La clé « #{name} » n'était plus présente sur #{target}." ]
    else
      [ :alert, "Impossible de supprimer la clé « #{name} » de #{target} : #{result.error_title} — #{result.error_details}" ]
    end

    respond_with_authorized_keys_refresh(@account, flash_type, message)
  end

  private

  def set_server_and_account
    @server = Server.find(params[:server_id])
    @account = authorized_keys_account(@server)
  end
end
