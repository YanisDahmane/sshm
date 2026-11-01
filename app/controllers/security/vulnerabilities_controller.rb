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

  # Everything about a CVE: description, the score of each provider with its
  # vector, exploitation, the packages and versions on the server it was
  # opened from (?server_id=), the other servers and images touched. In the
  # modal of the vulnerabilities lists (turbo-frame), or as a page.
  def show
    @cve = params[:cve].to_s.upcase
    @rows = ServerVulnerability.where(cve: @cve).includes(:server).to_a
    @feed_entries = Vulnerability.where(cve: @cve).order(:source, :release).to_a
    return head(:not_found) if @rows.empty? && @feed_entries.empty? && !CveScore.exists?(cve: @cve)

    @server = Server.find_by(id: params[:server_id])
    @server_rows = @server ? @rows.select { |row| row.server_id == @server.id } : []
    @rating = CveRating.find_by(cve: @cve)
    providers = ScoreProvider.all_providers.index_by(&:key)
    @scores = CveScore.where(cve: @cve).to_a.select { |score| providers[score.provider_key] }.sort_by { |score| providers[score.provider_key].position }
    @providers = providers
    @description = @feed_entries.filter_map(&:description).first || @rows.filter_map(&:description).first ||
                   @scores.filter_map { |score| score.data["description"] }.first
    @servers = @rows.group_by(&:server).sort_by { |server, _| server.name }
    render layout: !turbo_frame_request?
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
    @ratings = CveRating.for(@rows.map(&:cve))
  end
end
