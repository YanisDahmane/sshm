class ServerAuthorizationsController < ApplicationController
  include AuthorizedKeysRefresh

  require_permission :operate

  def create
    server = Server.find(params[:server_id])
    account = authorized_keys_account(server)
    public_key = PublicKey.find(params.expect(:public_key_id))
    duration = requested_duration
    result = AccessGrant.call(server, public_key, account: account, duration: duration)
    target = "« #{server.name} »"

    flash_type, message = if result.added? && duration
      [ :notice, "La clé « #{public_key.name} » est ajoutée sur #{target} pendant #{TemporaryAccess.label_for(duration)}, jusqu'à #{l(duration.from_now, format: :short)}." ]
    elsif result.added?
      [ :notice, "La clé « #{public_key.name} » a été ajoutée sur #{target}." ]
    elsif result.already_present?
      [ :notice, "La clé « #{public_key.name} » était déjà présente sur #{target}." ]
    else
      [ :alert, "Impossible d'ajouter « #{public_key.name} » sur #{target} : #{result.error_title} — #{result.error_details}" ]
    end

    respond_with_authorized_keys_refresh(account, flash_type, message)
  end

  private

  # nil (permanent) or one of TemporaryAccess::DURATIONS.
  def requested_duration
    TemporaryAccess.duration_for(params[:duration]) if params[:duration].present?
  rescue ArgumentError
    raise ActionController::BadRequest, "Invalid duration"
  end
end
