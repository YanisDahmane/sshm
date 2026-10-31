# Grants a keyring key access to several servers at once, or revokes one access,
# from the keyring key page.
class PublicKeyAccessesController < ApplicationController
  require_permission :operate

  before_action :set_public_key

  def create
    servers = Server.where(id: params[:server_ids]).order(:name)
    return redirect_to(public_key_path(@public_key), alert: "Choisissez au moins un serveur.") if servers.empty?

    @results = Keys::BulkAccess.grant([ @public_key ], servers, duration: requested_duration)

    respond_with_accesses(:notice, "Ajouts terminés : #{@results.count { |result| !result.error? }}/#{@results.size} serveur(s).")
  end

  def destroy
    server = Server.find(params.expect(:server_id))
    account = AuthorizedKeysAccount.login(server)
    result = Keys::Revocation.call(server, @public_key.authorized_key.key, account: account, key_name: @public_key.authorized_key.comment || @public_key.name, public_key: @public_key)

    if result.success?
      respond_with_accesses(:notice, "L'accès de « #{@public_key.name} » à « #{server.name} » a été retiré.")
    else
      respond_with_accesses(:alert, "Impossible de retirer l'accès : #{result.error_title} — #{result.error_details}")
    end
  end

  private

  def set_public_key
    @public_key = PublicKey.find(params[:public_key_id])
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
        streams = [ turbo_stream.replace("key-accesses", partial: "public_keys/accesses", locals: { public_key: @public_key }),
                    turbo_stream.update("flash", partial: "shared/flash") ]
        streams << turbo_stream.update("bulk-results", partial: "public_keys/bulk_results", locals: { results: @results }) if @results
        render turbo_stream: streams
      end
      format.html { redirect_to public_key_path(@public_key), flash: { flash_type => message }, status: :see_other }
    end
  end
end
