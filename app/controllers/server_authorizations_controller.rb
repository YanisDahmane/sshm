# Adds a key on a server's login account: a key of the keyring
# (public_key_id), or a new key (source=new, public_key[…]) saved to the
# keyring first. Optional duration (temporary access).
class ServerAuthorizationsController < ApplicationController
  include AuthorizedKeysRefresh

  require_permission :operate

  def create
    server = Server.find(params[:server_id])
    duration = requested_duration
    public_key = params[:source] == "new" ? create_public_key(server) : PublicKey.find(params.expect(:public_key_id))
    return unless public_key

    account = authorized_keys_account(server)
    result = AccessGrant.call(server, public_key, account: account, duration: duration)
    respond_with_authorized_keys_refresh(account, *grant_message(server, public_key, result, duration),
                                         streams: [ turbo_stream.replace(helpers.dom_id(server, :add_key), partial: "servers/add_key_dialog", locals: { server: server }) ])
  end

  private

  # nil (permanent) or one of TemporaryAccess::DURATIONS.
  def requested_duration
    TemporaryAccess.duration_for(params[:duration]) if params[:duration].present?
  rescue ArgumentError
    raise ActionController::BadRequest, "Invalid duration"
  end

  # Saves the new key to the keyring, or shows the dialog again with the errors.
  def create_public_key(server)
    public_key = PublicKey.new(params.expect(public_key: [ :name, :kind, :content, :description ]))
    if public_key.save
      Activity.record!(:public_key_created, public_key: public_key, fingerprint: public_key.fingerprint)
      @created = true
      return public_key
    end

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace(helpers.dom_id(server, :add_key), partial: "servers/add_key_dialog",
                                                  locals: { server: server, public_key: public_key, source: "new", open: true }),
               status: :unprocessable_entity
      end
      format.html do
        redirect_to server_path(server, tab: "keys"), alert: "Clé non enregistrée : #{public_key.errors.full_messages.to_sentence}", status: :see_other
      end
    end
    nil
  end

  def grant_message(server, public_key, result, duration)
    target = "« #{server.name} »"
    name = "La clé « #{public_key.name} »#{" (ajoutée au trousseau)" if @created}"

    if result.added? && duration
      [ :notice, "#{name} est ajoutée sur #{target} pendant #{TemporaryAccess.label_for(duration)}, jusqu'à #{l(duration.from_now, format: :short)}." ]
    elsif result.added?
      [ :notice, "#{name} a été ajoutée sur #{target}." ]
    elsif result.already_present?
      [ :notice, "#{name} était déjà présente sur #{target}." ]
    else
      [ :alert, "Impossible d'ajouter « #{public_key.name} » sur #{target}#{" (elle reste dans le trousseau)" if @created} : #{result.error_title} — #{result.error_details}" ]
    end
  end
end
