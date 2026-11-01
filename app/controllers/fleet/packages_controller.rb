# Packages of the whole fleet: a search shows, for each matching package
# name, its versions and the servers that have them; without a search, the
# pending security updates. Paged by package name.
class PackagesController < ApplicationController
  RESULTS_PER_PAGE = 25
  SECURITY_PER_PAGE = 50

  def index
    @q = params[:q].to_s.strip.first(100)
    if @q.present?
      matching = Inventory::Package.search(@q)
      @pager = paginate(matching.distinct.order(:name).pluck(:name), per_page: RESULTS_PER_PAGE)
      @results = matching.where(name: @pager.records).includes(:server).order(:name, :version).group_by(&:name)
      @versions = @results.transform_values { |rows| rows.group_by(&:version) }
    else
      security = Inventory::Package.security
      @pager = paginate(security.distinct.order(:name).pluck(:name), per_page: SECURITY_PER_PAGE)
      @security = security.where(name: @pager.records).includes(:server).order(:name).group_by(&:name)
    end
    @servers_without_inventory = Server.where.not(id: Inventory::Package.select(:server_id)).count
  end
end
