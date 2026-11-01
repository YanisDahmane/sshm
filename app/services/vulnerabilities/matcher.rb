# Finds the CVEs affecting a server from its dpkg packages (by source package
# and source version) and the feed of its release: a CVE without a fix yet, or
# fixed in a version newer than the installed one. Replaces the server's
# ServerVulnerability rows of that origin; logs vulnerability_found for the
# fixable ones at the alert severity (AppSetting) that are new since the
# previous match (never on the first one).
module Vulnerabilities::Matcher
  Package = Data.define(:name, :source, :version)

  def self.call_all
    Server.includes(:inventory_snapshots).find_each { |server| call(server) }
  end

  def self.call(server, refresh_health: true)
    target = Vulnerabilities.target(server.inventory("os")&.data)
    return unless target && VulnerabilityFeed.for(target.first).refreshed_at

    packages = server.packages.where(manager: "dpkg").pluck(:name, :source_name, :source_version, :version)
                     .map { |name, source, source_version, version| Package.new(name, source || name, source_version || version) }
    rows = affected(*target, packages).map { |row| row.merge(server_id: server.id, origin: "host", image: nil) }
    replace(server, rows, origin: "host", log: server.vulnerabilities_checked_at.present?)
    server.update_columns(vulnerabilities_checked_at: Time.current)
    server.refresh_health! if refresh_health
  end

  # CVEs of `packages` (Package) in a feed release: rows without server_id.
  def self.affected(source, release, packages)
    by_source = packages.group_by(&:source)
    return [] if by_source.empty?

    Vulnerability.where(source: source, release: release, package: by_source.keys)
                 .pluck(:package, :cve, :fixed_version, :severity, :description).filter_map do |package, cve, fixed, severity, description|
      installed = by_source.fetch(package).map(&:version).compact.min { |left, right| Inventory::DebianVersion.compare(left, right) }
      next if fixed && installed && !Inventory::DebianVersion.older?(installed, fixed)

      { source: source, cve: cve, source_package: package, packages: by_source.fetch(package).map(&:name).uniq.sort,
        installed_version: installed, fixed_version: fixed, severity: severity, description: description }
    end
  end

  # Replaces the rows of an origin (and image), logging the new serious ones
  # when `log` (not on a first match).
  def self.replace(server, rows, origin:, image: :all, log: true)
    scope = server.server_vulnerabilities.where(origin: origin)
    scope = scope.where(image: image) unless image == :all
    known = scope.pluck(:cve).to_set
    ServerVulnerability.transaction do
      scope.delete_all
      ServerVulnerability.insert_all(rows) if rows.any?
    end
    log_new(server, rows, known) if log
  end

  def self.log_new(server, rows, known)
    minimum = AppSetting.current.vulnerability_alert_severity
    return if minimum == "none"

    serious = rows.select { |row| row[:fixed_version] && row[:severity].in?(Vulnerability.severities_from(minimum)) && !known.include?(row[:cve]) }
    return if serious.empty?

    cves = serious.sort_by { |row| -Vulnerability.severity_rank(row[:severity]) }.map { |row| row[:cve] }.uniq
    Activity.record!(:vulnerability_found, server: server, user: nil, count: cves.size, cves: cves.first(5),
                                           packages: serious.map { |row| row[:source_package] }.uniq.first(5), image: serious.first[:image])
  end
  private_class_method :log_new
end
