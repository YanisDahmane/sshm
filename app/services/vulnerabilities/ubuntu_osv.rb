# Ubuntu vulnerabilities in the OSV format, one archive per release
# (osv-vulnerabilities…/Ubuntu:24.04:LTS/all.zip, ≈ 140 MB; the one of every
# release, Ubuntu/all.zip, weighs 800 MB): one JSON per UBUNTU-CVE-… record
# (or per USN), read entry by entry:
#
#   { "id": "UBUNTU-CVE-2024-6387", "details": "…", "related": ["CVE-2024-6387", "USN-6859-1"],
#     "affected": [{ "package": { "ecosystem": "Ubuntu:24.04:LTS", "name": "openssh" },
#                    "ranges": [{ "type": "ECOSYSTEM", "events": [{ "introduced": "0" }, { "fixed": "1:9.6p1-3ubuntu13.3" }] }],
#                    "ecosystem_specific": { "ubuntu_priority": "high" } }] }
#
# Package names are source packages; no "fixed" event: no fix yet. Ubuntu
# Pro / FIPS ecosystems are skipped, "negligible" issues too. The USN
# records repeat the CVEs of the UBUNTU-CVE ones without their priority:
# their rows are not `primary` and never replace those (Vulnerabilities::Update).
module Vulnerabilities::UbuntuOsv
  # %{ecosystem}: "Ubuntu:24.04:LTS", "Ubuntu:24.10" (URL-encoded).
  URL = ENV.fetch("ELIO_UBUNTU_OSV_URL", "https://osv-vulnerabilities.storage.googleapis.com/%{ecosystem}/all.zip")
  PRIORITIES = { "critical" => "critical", "high" => "high", "medium" => "medium", "low" => "low", "untriaged" => "unknown" }.freeze
  ECOSYSTEM = /\AUbuntu:(\d+\.\d+)(?::LTS)?\z/
  CVE = /\A(?:UBUNTU-)?(CVE-\d+-\d+)\z/
  MAX_ENTRY = 5.megabytes

  # LTS releases are the .04 of even years (22.04, 24.04).
  def self.ecosystem(release)
    year, month = release.split(".").map(&:to_i)
    year.even? && month == 4 ? "Ubuntu:#{release}:LTS" : "Ubuntu:#{release}"
  end

  def self.url(release) = format(URL, ecosystem: ERB::Util.url_encode(ecosystem(release)))

  def self.each_row(path, releases:)
    releases = releases.to_set
    each_record(path) { |record| rows(record, releases).each { |row| yield row } }
  end

  # Releases an archive is about: those of every record (the archive of a
  # release also lists the other releases its CVEs touch), nil when there is
  # none in common (the archive of every release).
  def self.archive_releases(path)
    common = nil
    each_record(path) do |record|
      releases = Array(record["affected"]).filter_map { |affected| affected.dig("package", "ecosystem").to_s[ECOSYSTEM, 1] }.to_set
      common = common ? common & releases : releases
    end
    common.presence&.to_a&.sort
  end

  def self.each_record(path)
    Zip::File.open(path) do |zip|
      zip.each do |entry|
        next unless entry.file? && entry.name.end_with?(".json") && entry.size <= MAX_ENTRY

        yield JSON.parse(entry.get_input_stream.read)
      end
    end
  rescue Zip::Error, JSON::ParserError => e
    raise Vulnerabilities::Error, "Archive OSV d'Ubuntu illisible : #{e.message.truncate(120)}"
  end

  def self.rows(record, releases)
    primary = record["id"].to_s.start_with?("UBUNTU-CVE-")
    cves = ([ record["id"] ] + Array(record["related"]) + Array(record["upstream"])).filter_map { |id| id.to_s[CVE, 1] }.uniq
    cves = cves.first(1) if primary
    return [] if cves.empty?

    default_priority = Array(record["severity"]).find { |severity| severity["type"] == "Ubuntu" }&.dig("score")
    description = (record["summary"].presence || record["details"].to_s).squish.truncate(240).presence

    Array(record["affected"]).flat_map do |affected|
      release = affected.dig("package", "ecosystem").to_s[ECOSYSTEM, 1]
      package = affected.dig("package", "name")
      next [] unless release && package && releases.include?(release)

      priority = (affected.dig("ecosystem_specific", "ubuntu_priority") || default_priority || "untriaged").to_s.downcase
      severity = PRIORITIES[priority] or next []
      fixed = Array(affected["ranges"]).flat_map { |range| Array(range["events"]) }.filter_map { |event| event["fixed"] }.first
      cves.map { |cve| { release: release, package: package, cve: cve, fixed_version: fixed, severity: severity, description: description, primary: primary } }
    end
  end
end
