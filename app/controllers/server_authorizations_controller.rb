class ServerAuthorizationsController < ApplicationController
  include AuthorizedKeysRefresh

  def create
    server = Server.find(params[:server_id])
    account = authorized_keys_account(server)
    profile = Profile.find(params.expect(:profile_id))
    result = ProfileAuthorization.call(server, profile, account: account)
    target = "« #{server.name} » pour #{account.unix_user}"

    flash_type, message = if result.added?
      [ :notice, "Le profil « #{profile.name} » est maintenant autorisé sur #{target}." ]
    elsif result.already_present?
      [ :notice, "Le profil « #{profile.name} » était déjà autorisé sur #{target}." ]
    else
      [ :alert, "Impossible d'autoriser « #{profile.name} » sur #{target} : #{result.error_title} — #{result.error_details}" ]
    end

    respond_with_authorized_keys_refresh(account, flash_type, message)
  end
end
