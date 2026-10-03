# Imports servers from a CSV file or an ~/.ssh/config extract: `preview`
# parses and shows what would happen, `create` parses the same text again and
# creates the valid rows (nothing is kept on the server between the two).
class ServerImportsController < ApplicationController
  require_permission :operate

  def new
    @format = "csv"
    @default_username = "root"
  end

  def preview
    read_params
    @rows = ServerImport.parse(@text, format: @format, default_username: @default_username)
    render :new
  rescue ServerImport::Error => e
    flash.now[:alert] = e.message
    render :new, status: :unprocessable_entity
  end

  def create
    read_params
    servers = ServerImport.import!(ServerImport.parse(@text, format: @format, default_username: @default_username))
    return redirect_to(new_server_import_path, alert: "Aucun serveur valide à importer.") if servers.empty?

    Activity.record!(:servers_imported, count: servers.size, format: ServerImport::FORMATS.fetch(@format), names: servers.first(10).map(&:name))
    redirect_to servers_path, notice: "#{servers.size} serveur(s) importé(s). Installez-y la clé de SSHM puis lancez un scan des clés."
  rescue ServerImport::Error => e
    redirect_to new_server_import_path, alert: e.message
  rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique => e
    redirect_to new_server_import_path, alert: "Import annulé, rien n'a été créé : #{e.message}"
  end

  private

  def read_params
    @format = ServerImport::FORMATS.key?(params[:import_format]) ? params[:import_format] : "csv"
    @default_username = params[:default_username].to_s.strip.presence || "root"
    @text = params[:file].respond_to?(:read) ? params[:file].read(ServerImport::MAX_SIZE + 1) : params[:content].to_s
  end
end
