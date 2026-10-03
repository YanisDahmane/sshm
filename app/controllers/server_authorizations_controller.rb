class ServerAuthorizationsController < ApplicationController
  def create
    @server = Server.find(params[:server_id])
    profile = Profile.find(params.expect(:profile_id))
    result = ProfileAuthorization.call(@server, profile)

    flash_type, message = if result.added?
      [ :notice, "Le profil « #{profile.name} » est maintenant autorisé sur « #{@server.name} »." ]
    elsif result.already_present?
      [ :notice, "Le profil « #{profile.name} » était déjà autorisé sur « #{@server.name} »." ]
    else
      [ :alert, "Impossible d'autoriser « #{profile.name} » : #{result.error_title} — #{result.error_details}" ]
    end

    respond_to do |format|
      format.turbo_stream do
        flash.now[flash_type] = message
        render turbo_stream: [
          turbo_stream.replace(helpers.dom_id(@server, :authorized_keys), partial: "server_authorized_keys/frame", locals: { server: @server, loading: :eager }),
          turbo_stream.update("flash", partial: "shared/flash")
        ]
      end
      format.html { redirect_to server_path(@server), flash: { flash_type => message } }
    end
  end
end
