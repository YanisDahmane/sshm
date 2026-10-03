class ServerAuthorizedKeysController < ApplicationController
  include AuthorizedKeysRefresh

  require_permission :operate, only: :destroy

  before_action :set_server_and_account

  def index
    @result = AuthorizedKeysReader.call(@server, account: @account)
    record_ssh_status
    @accounts = @result.success? ? ServerAccountsReader.call(@server).accounts : [ @account ]
    @accounts |= [ @account ]
    @app_key = SshKey.current
    @profiles_by_fingerprint = Profile.where(fingerprint: @result.keys.map(&:fingerprint)).index_by(&:fingerprint)
    @authorizable_profiles = Profile.where.not(fingerprint: @profiles_by_fingerprint.keys).order(:name) if @result.success?
    @orphan_keys = @result.keys.reject { |key| key.matches?(@app_key) || @profiles_by_fingerprint.key?(key.fingerprint) }
    @temporary_accesses = TemporaryAccess.active.where(server: @server, unix_user: @account.unix_user).index_by(&:fingerprint)
  end

  # Removes the key whose base64 blob is params[:key] from the account's file.
  def destroy
    name = params[:name].presence || "sans nom"
    result = KeyRevocation.call(@server, params.expect(:key), account: @account, key_name: params[:name].presence)
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

  # A successful read proves the app can log in (and refreshes the account's
  # snapshot); a refused key proves it cannot.
  def record_ssh_status
    if @result.success?
      @server.record_ssh_status!(true)
      AccountSnapshot.record!(@server, @account, @result.keys)
    elsif @result.reason == :key_refused
      @server.record_ssh_status!(false)
    end
  end

  def set_server_and_account
    @server = Server.find(params[:server_id])
    @account = authorized_keys_account(@server)
  end
end
