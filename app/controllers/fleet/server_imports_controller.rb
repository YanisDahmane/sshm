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
    @rows = Servers::Import.parse(@text, format: @format, default_username: @default_username)
    render :new
  rescue Servers::Import::Error => e
    flash.now[:alert] = e.message
    render :new, status: :unprocessable_entity
  end

  def create
    read_params
    servers = Servers::Import.import!(Servers::Import.parse(@text, format: @format, default_username: @default_username))
    return redirect_to(new_server_import_path, alert: t("server_imports_controller.nothing")) if servers.empty?

    Activity.record!(:servers_imported, count: servers.size, format: Servers::Import::FORMATS.fetch(@format), names: servers.first(10).map(&:name))
    redirect_to servers_path, notice: t("server_imports_controller.imported", count: servers.size)
  rescue Servers::Import::Error => e
    redirect_to new_server_import_path, alert: e.message
  rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique => e
    redirect_to new_server_import_path, alert: t("server_imports_controller.cancelled", message: e.message)
  end

  private

  def read_params
    @format = Servers::Import::FORMATS.key?(params[:import_format]) ? params[:import_format] : "csv"
    @default_username = params[:default_username].to_s.strip.presence || "root"
    @text = params[:file].respond_to?(:read) ? params[:file].read(Servers::Import::MAX_SIZE + 1) : params[:content].to_s
  end
end
