class ServerAuthorizationsController < ApplicationController
  include AuthorizedKeysRefresh

  def create
    server = Server.find(params[:server_id])
    account = authorized_keys_account(server)
    profile = Profile.find(params.expect(:profile_id))
    duration = requested_duration
    result = AccessGrant.call(server, profile, account: account, duration: duration)
    target = "« #{server.name} » pour #{account.unix_user}"

    flash_type, message = if result.added? && duration
      [ :notice, "Le profil « #{profile.name} » est autorisé sur #{target} pendant #{TemporaryAccess.label_for(duration)}, jusqu'à #{l(duration.from_now, format: :short)}." ]
    elsif result.added?
      [ :notice, "Le profil « #{profile.name} » est maintenant autorisé sur #{target}." ]
    elsif result.already_present?
      [ :notice, "Le profil « #{profile.name} » était déjà autorisé sur #{target}." ]
    else
      [ :alert, "Impossible d'autoriser « #{profile.name} » sur #{target} : #{result.error_title} — #{result.error_details}" ]
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
