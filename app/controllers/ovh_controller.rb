# "OVHcloud" (extension): services (dedicated, VPS, instances), IP blocks and
# DNS records, with the server each one belongs to.
class OvhController < ApplicationController
  include RequiresIntegration

  PER_PAGE = 100
  TABS = %w[services ips dns].freeze

  requires_integration :ovh

  def index
    @tab = params[:tab].presence_in(TABS) || "services"
    @q = params[:q].to_s.strip.first(100)
    @counts = OvhResource.group(:kind).count
    @unattached_services = OvhResource.services.unattached.count
    @outside_records = Integrations::Ovh.records_outside_fleet.count
    @expiring = Integrations::Ovh.expiring_services(@integration).count

    scope = case @tab
    when "services" then OvhResource.services.order(:kind, :name)
    when "ips" then OvhResource.of_kind("ip").order(:name)
    else OvhResource.of_kind("dns_record").order(Arel.sql("ovh_resources.data->>'zone'"), :name)
    end
    scope = scope.unattached if params[:unattached] == "1"
    scope = scope.where("ovh_resources.name ILIKE :q OR ovh_resources.data::text ILIKE :q", q: "%#{OvhResource.sanitize_sql_like(@q)}%") if @q.present?
    @pager = paginate(scope.includes(:server), per_page: PER_PAGE)
  end
end
