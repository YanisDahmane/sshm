# Fixes drift from the drift page: adds the missing keys (of one account, or
# of every account), or removes one extra key from one account.
class DriftFixesController < ApplicationController
  require_permission :operate

  def create
    report = DriftDetector.call
    entries = if params[:server_id].present?
      server = Server.find(params[:server_id])
      Array(report.entry_for(server, params.expect(:account)))
    else
      report.drifts
    end

    results = DriftCorrection.add_missing(entries)
    return redirect_to(drift_path, alert: "Aucune clé manquante à ajouter.", status: :see_other) if results.empty?

    failures = results.select(&:error?)
    message = "#{results.size - failures.size}/#{results.size} clé(s) manquante(s) ajoutée(s)."
    message += " Échecs : #{failures.map { |result| "#{result.profile&.name || "?"} sur #{result.server.name} (#{result.message})" }.join(", ")}." if failures.any?
    redirect_to drift_path, flash: { (failures.any? ? :alert : :notice) => message }, status: :see_other
  end

  def destroy
    server = Server.find(params.expect(:server_id))
    account = AuthorizedKeysAccount.for(server, params.expect(:account))
    blob = params.expect(:key)
    profile = Profile.all.find { |candidate| candidate.authorized_key&.key == blob }
    result = KeyRevocation.call(server, blob, account: account, key_name: params[:name].presence || profile&.name, profile: profile)

    if result.success?
      redirect_to drift_path, notice: "Clé « #{params[:name].presence || "sans nom"} » retirée de « #{server.name} » pour #{account.unix_user}.", status: :see_other
    else
      redirect_to drift_path, alert: "Impossible de retirer la clé : #{result.error_title} — #{result.error_details}", status: :see_other
    end
  rescue ArgumentError
    raise ActionController::BadRequest, "Invalid account"
  end
end
