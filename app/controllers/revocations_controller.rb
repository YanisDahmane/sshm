# "Révoquer partout": removes a profile's key from every server (admins only).
class RevocationsController < ApplicationController
  require_permission :administer

  before_action :set_revocation, only: %i[show retry]

  def create
    profile = Profile.find(params[:profile_id])
    revocation = Revocation.start!(profile, by: current_user, delete_profile: params[:delete_profile] == "1")
    RevokeProfileEverywhereJob.perform_later(revocation)

    redirect_to revocation_path(revocation), notice: "Révocation de « #{profile.name} » lancée sur #{helpers.pluralize(revocation.servers_count, "serveur", plural: "serveurs")}."
  end

  def show
  end

  def retry
    return redirect_to(revocation_path(@revocation), alert: "Rien à relancer.") if @revocation.running? || @revocation.failed_count.zero?

    @revocation.update!(finished_at: nil)
    RevokeProfileEverywhereJob.perform_later(@revocation, retry_failed: true)
    redirect_to revocation_path(@revocation), notice: "Relance des échecs en cours."
  end

  private

  def set_revocation
    @revocation = Revocation.find(params[:id])
  end
end
