# Packages across the fleet: search a package to see which servers have it
# and in which version, or the security updates waiting on the fleet.
class PackagesController < ApplicationController
  def index
    @q = params[:q].to_s.strip.first(100)
    if @q.present?
      packages = Inventory::Package.search(@q).includes(:server).order(:name, :version)
      @results = packages.group_by(&:name).first(50).to_h
      @versions = @results.transform_values { |rows| rows.group_by(&:version) }
    else
      @security = Inventory::Package.security.includes(:server).order(:name).group_by(&:name)
    end
    @servers_without_inventory = Server.where.not(id: Inventory::Package.select(:server_id)).count
  end
end
