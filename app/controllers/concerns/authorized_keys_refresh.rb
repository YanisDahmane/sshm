# Shared by actions working on a server's authorized_keys (see
# AuthorizedKeysAccount): after a change, reloads the key list frame and shows
# the flash over Turbo Stream, or redirects to the server page without
# JavaScript.
module AuthorizedKeysRefresh
  extend ActiveSupport::Concern

  private

  def authorized_keys_account(server) = AuthorizedKeysAccount.login(server)

  def respond_with_authorized_keys_refresh(account, flash_type, message)
    respond_to do |format|
      format.turbo_stream do
        flash.now[flash_type] = message
        render turbo_stream: [
          turbo_stream.replace(helpers.dom_id(account.server, :authorized_keys), partial: "server_authorized_keys/frame",
                                                                                  locals: { server: account.server, loading: :eager }),
          turbo_stream.update("flash", partial: "shared/flash")
        ]
      end
      format.html { redirect_to server_path(account.server), flash: { flash_type => message }, status: :see_other }
    end
  end
end
