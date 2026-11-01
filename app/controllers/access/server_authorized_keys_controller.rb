class ServerAuthorizedKeysController < ApplicationController
  include AuthorizedKeysRefresh

  require_permission :operate, only: :destroy

  before_action :set_server_and_account

  def index
    @result = Keys::AuthorizedKeysReader.call(@server, account: @account)
    record_ssh_status
    @app_key = SshKey.app_keys
    @public_keys_by_fingerprint = PublicKey.where(fingerprint: @result.keys.map(&:fingerprint)).index_by(&:fingerprint)
    @orphan_keys = @result.keys.reject { |key| key.matches?(@app_key) || @public_keys_by_fingerprint.key?(key.fingerprint) }
    @temporary_accesses = TemporaryAccess.active.where(server: @server, unix_user: @account.unix_user).index_by(&:fingerprint)
  end

  # Removes the key whose base64 blob is params[:key] from the account's file.
  def destroy
    name = params[:name].presence || t("server_authorized_keys_controller.unnamed")
    result = Keys::Revocation.call(@server, params.expect(:key), account: @account, key_name: params[:name].presence)
    target = t("server_authorized_keys_controller.target", server_name: @server.name)

    flash_type, message = if result.removed?
      [ :notice, t("server_authorized_keys_controller.deleted", name: name, target: target) ]
    elsif result.absent?
      [ :notice, t("server_authorized_keys_controller.absent", name: name, target: target) ]
    else
      [ :alert, t("server_authorized_keys_controller.failed", name: name, target: target, error_title: result.error_title, error_details: result.error_details) ]
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
