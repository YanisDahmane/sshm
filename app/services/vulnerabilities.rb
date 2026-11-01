# Vulnerabilities (CVE) of the packages of the fleet: feeds (Debian Security
# Tracker, Ubuntu OSV) downloaded every day or imported by hand, matched with
# the packages already inventoried (no new command on the servers).
module Vulnerabilities
  class Error < StandardError; end

  # Feed of a system ({ "id" => "debian", "codename" => "bookworm" } from the
  # os inventory or a Docker image): ["debian", "bookworm"], ["ubuntu", "24.04"], or nil.
  def self.target(os_data)
    os_data ||= {}
    case os_data["id"]
    when "debian", "raspbian" then [ "debian", os_data["codename"] ].then { |target| target if target.last.present? }
    when "ubuntu" then [ "ubuntu", os_data["version_id"].to_s[/\A\d+\.\d+/] ].then { |target| target if target.last.present? }
    end
  end

  # Releases of each feed to keep: those of the servers (and of their Docker
  # images): { "debian" => ["bookworm", "trixie"], "ubuntu" => ["24.04"] }.
  def self.releases
    systems = Inventory::Snapshot.where(category: "os").where.not(collected_at: nil).pluck(:data) +
              Inventory::Snapshot.where(category: "docker").where.not(collected_at: nil).pluck(:data).flat_map { |data| Array(data["images"]).filter_map { |image| image["os"] } }
    targets = systems.filter_map { |data| target(data) }.uniq
    Vulnerability::SOURCES.keys.index_with { |source| targets.select { |feed, _| feed == source }.map(&:last).sort }
  end

  # A server on a release that its feed does not hold yet — the first server
  # of a new installation, an upgrade to a new release — gets its
  # vulnerabilities now rather than at the next daily download. Not again
  # within an hour of a download, nor after a failure (a closed network).
  def self.cover(server)
    source, release = target(server.inventory("os")&.data)
    return unless source

    feed = VulnerabilityFeed.for(source)
    return if Array(feed.releases).include?(release) || feed.failed? || feed.refreshed_at&.after?(1.hour.ago)

    Automation.trigger(:vulnerabilities_update)
  end
end
