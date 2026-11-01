# Vulnerabilities of the whole fleet, by CVE: the servers (and images) it
# touches, whether a fix exists. Filters: ?q= (CVE or package), ?severity=
# (minimum), ?group=, ?fixable=1, ?origin=host|image. Fixable and most
# serious first.
class VulnerabilitiesController < ApplicationController
  PER_PAGE = 100
  Row = Data.define(:cve, :severity, :packages, :servers, :images, :fixable, :description, :source) do
    def rank = [ fixable ? 0 : 1, -Vulnerability.severity_rank(severity), -servers.size, cve ]
    def url = Vulnerability.url(cve, source)
  end

  def index
    @groups = ServerGroup.order(:name)
    @group = @groups.find { |group| group.id.to_s == params[:group].to_s } if params[:group].present?
    @q = params[:q].to_s.strip.first(100)
    @severity = params[:severity].presence_in(Vulnerability::SEVERITIES.keys)
    @fixable_only = params[:fixable] == "1"
    @origin = params[:origin].presence_in(ServerVulnerability::ORIGINS.keys)
    @feeds = VulnerabilityFeed.where.not(refreshed_at: nil).order(:source).to_a

    scope = ServerVulnerability.all
    scope = scope.where(server_id: Server.in_group(@group).select(:id)) if @group
    scope = scope.at_least(@severity) if @severity
    scope = scope.fixable if @fixable_only
    scope = scope.where(origin: @origin) if @origin
    scope = scope.where("server_vulnerabilities.cve ILIKE :q OR server_vulnerabilities.source_package ILIKE :q", q: "%#{ServerVulnerability.sanitize_sql_like(@q)}%") if @q.present?

    servers = Server.where(id: scope.select(:server_id)).index_by(&:id)
    rows = scope.pluck(:cve, :severity, :source_package, :server_id, :image, :fixed_version, :description, :source).group_by(&:first).map do |cve, entries|
      Row.new(cve: cve, severity: entries.map { |entry| entry[1] }.max_by { |severity| Vulnerability.severity_rank(severity) },
              packages: entries.map { |entry| entry[2] }.uniq.sort, servers: entries.map { |entry| servers[entry[3]] }.compact.uniq.sort_by(&:name),
              images: entries.filter_map { |entry| entry[4] }.uniq.sort, fixable: entries.any? { |entry| entry[5] },
              description: entries.filter_map { |entry| entry[6] }.first, source: entries.first[7])
    end
    @summary = { cves: rows.size, fixable: rows.count(&:fixable), servers: servers.size,
                 serious: rows.count { |row| row.fixable && row.severity.in?(%w[critical high]) } }
    @pager = paginate(rows.sort_by(&:rank), per_page: PER_PAGE)
    @rows = @pager.records
  end
end
