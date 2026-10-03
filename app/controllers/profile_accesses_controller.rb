# Grants a profile access to several servers at once, or revokes one access,
# from the profile page.
class ProfileAccessesController < ApplicationController
  require_permission :operate

  before_action :set_profile

  def create
    servers = Server.where(id: params[:server_ids]).order(:name)
    return redirect_to(profile_path(@profile), alert: "Choisissez au moins un serveur.") if servers.empty?

    @results = BulkAccess.grant([ @profile ], servers, account: params[:account], duration: requested_duration)

    respond_with_accesses(:notice, "Autorisations terminées : #{@results.count { |result| !result.error? }}/#{@results.size} serveur(s).")
  end

  def destroy
    server = Server.find(params.expect(:server_id))
    account = AuthorizedKeysAccount.for(server, params.expect(:account))
    result = KeyRevocation.call(server, @profile.authorized_key.key, account: account, key_name: @profile.authorized_key.comment || @profile.name, profile: @profile)

    if result.success?
      respond_with_accesses(:notice, "L'accès de « #{@profile.name} » à « #{server.name} » pour #{account.unix_user} a été retiré.")
    else
      respond_with_accesses(:alert, "Impossible de retirer l'accès : #{result.error_title} — #{result.error_details}")
    end
  rescue ArgumentError
    raise ActionController::BadRequest, "Invalid account"
  end

  private

  def set_profile
    @profile = Profile.find(params[:profile_id])
  end

  def requested_duration
    TemporaryAccess.duration_for(params[:duration]) if params[:duration].present?
  rescue ArgumentError
    raise ActionController::BadRequest, "Invalid duration"
  end

  def respond_with_accesses(flash_type, message)
    respond_to do |format|
      format.turbo_stream do
        flash.now[flash_type] = message
        streams = [ turbo_stream.replace("profile-accesses", partial: "profiles/accesses", locals: { profile: @profile }),
                    turbo_stream.update("flash", partial: "shared/flash") ]
        streams << turbo_stream.update("bulk-results", partial: "profiles/bulk_results", locals: { results: @results }) if @results
        render turbo_stream: streams
      end
      format.html { redirect_to profile_path(@profile), flash: { flash_type => message }, status: :see_other }
    end
  end
end
