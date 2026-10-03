# Shared by actions working on one account's authorized_keys (see
# AuthorizedKeysAccount): picks the account from params[:account] (the login
# user by default) and, after a change, reloads the key list frame on that
# account and shows the flash over Turbo Stream, or redirects to the server
# page without JavaScript.
module AuthorizedKeysRefresh
  extend ActiveSupport::Concern

  private

  def authorized_keys_account(server)
    AuthorizedKeysAccount.for(server, params[:account].presence || server.username)
  rescue ArgumentError
    raise ActionController::BadRequest, "Invalid account"
  end

  def respond_with_authorized_keys_refresh(account, flash_type, message)
    respond_to do |format|
      format.turbo_stream do
        flash.now[flash_type] = message
        render turbo_stream: [
          turbo_stream.replace(helpers.dom_id(account.server, :authorized_keys), partial: "server_authorized_keys/frame",
                                                                                  locals: { account: account, loading: :eager }),
          turbo_stream.update("flash", partial: "shared/flash")
        ]
      end
      format.html { redirect_to server_path(account.server), flash: { flash_type => message }, status: :see_other }
    end
  end
end
