# Grants (create) or revokes (destroy) every profile of a team on the chosen
# servers, through BulkAccess, from the team page.
class TeamAccessesController < ApplicationController
  require_permission :operate

  before_action :set_team

  def create
    run do |profiles, servers|
      BulkAccess.grant(profiles, servers, account: params[:account], duration: requested_duration)
    end
  end

  def destroy
    run do |profiles, servers|
      BulkAccess.revoke(profiles, servers, account: params[:account])
    end
  end

  private

  def set_team
    @team = Team.find(params[:team_id])
  end

  def run
    servers = Server.where(id: params[:server_ids]).order(:name)
    profiles = @team.profiles.to_a
    return respond_with_results(:alert, "Choisissez au moins un serveur.") if servers.empty?
    return respond_with_results(:alert, "L'équipe n'a aucun profil.") if profiles.empty?

    @results = yield profiles, servers
    failures = @results.count(&:error?)
    verb = action_name == "create" ? "Autorisation" : "Retrait"
    message = "#{verb} de l'équipe « #{@team.name} » terminé : #{@results.size - failures}/#{@results.size} accès traités#{", #{failures} échec(s)" if failures.positive?}."
    respond_with_results(failures.positive? ? :alert : :notice, message)
  end

  def requested_duration
    TemporaryAccess.duration_for(params[:duration]) if params[:duration].present?
  rescue ArgumentError
    raise ActionController::BadRequest, "Invalid duration"
  end

  def respond_with_results(flash_type, message)
    respond_to do |format|
      format.turbo_stream do
        flash.now[flash_type] = message
        streams = [ turbo_stream.update("flash", partial: "shared/flash") ]
        streams << turbo_stream.update("team-bulk-results", partial: "profiles/bulk_results", locals: { results: @results, show_profile: true }) if @results
        render turbo_stream: streams
      end
      format.html { redirect_to team_path(@team), flash: { flash_type => message }, status: :see_other }
    end
  end
end
