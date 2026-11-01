# Manual attachment of an OVHcloud resource to a server (or to none), kept
# across synchronizations (IntegrationLink); DELETE returns to the automatic one
# (applied at the next synchronization).
class OvhLinksController < ApplicationController
  include RequiresIntegration

  requires_integration :ovh
  require_permission :operate

  def create
    resource = OvhResource.find(params[:ovh_resource_id])
    server = Server.find(params[:server_id]) if params[:server_id].present?
    @integration.links.find_or_initialize_by(external_id: resource.link_key).update!(server: server, user: current_user)
    previous = resource.server
    resource.update!(server: server, matched_by: server ? "manual" : nil, matched_address: nil)
    [ previous, server ].compact.uniq.each(&:refresh_health!)

    redirect_back_or_to ovh_path, notice: server ? "« #{resource.name} » rattaché à « #{server.name} »." : "« #{resource.name} » rattaché à aucun serveur."
  end

  def destroy
    resource = OvhResource.find(params[:ovh_resource_id])
    @integration.links.where(external_id: resource.link_key).delete_all
    task = @integration.enqueue_sync!

    redirect_back_or_to task_path(task), notice: "« #{resource.name} » : retour au rattachement automatique (synchronisation lancée).", status: :see_other
  end
end
