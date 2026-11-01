# System of a server: distribution (/etc/os-release), kernel, architecture,
# host name, virtualization, boot time, CPUs, memory and time zone. One
# read-only command, its sections separated by "@@elio <name>" lines.
class Inventory::Collectors::Os < Inventory::Collector
  # A boot time that moves by less than this is the same boot (rounding of /proc/uptime).
  REBOOT_TOLERANCE = 5.minutes

  def collect
    result = run("inventory.os")
    raise Error, I18n.t("inventory.collectors.os.failed", exit_status: (result.stderr.strip.presence || "code #{result.exit_status}")) if result.stdout.blank?

    ok(self.class.parse(result.stdout))
  end

  def self.parse(output, now: Time.current)
    sections = sections(output)
    release = parse_os_release(sections["os-release"])
    kernel, arch = parse_uname(sections["uname"])
    uptime = sections["uptime"].to_s.split.first&.to_f&.round

    {
      "name" => release["PRETTY_NAME"].presence || [ release["NAME"], release["VERSION"] ].compact.join(" ").presence || "Inconnu",
      "id" => release["ID"],
      "id_like" => release["ID_LIKE"],
      "version_id" => release["VERSION_ID"],
      "codename" => release["VERSION_CODENAME"].presence || release["UBUNTU_CODENAME"],
      "kernel" => kernel,
      "arch" => arch,
      "hostname" => sections["hostname"].to_s.strip.presence,
      "virtualization" => parse_virt(sections["virt"]),
      "booted_at" => (uptime && (now - uptime).utc.iso8601),
      "cpus" => sections["cpus"].to_s[/\d+/]&.to_i,
      "memory_bytes" => sections["meminfo"].to_s[/MemTotal:\s+(\d+)\s*kB/, 1]&.to_i&.*(1024),
      "timezone" => sections["timezone"].to_s.strip.presence
    }.compact
  end

  def self.changes(previous, data)
    changes = []
    if previous["version_id"].present? && data["version_id"].present? && previous["version_id"] != data["version_id"]
      changes << { kind: :os_upgraded, data: { from: previous["name"], to: data["name"] } }
    end
    if previous["booted_at"] && data["booted_at"] && Time.iso8601(data["booted_at"]) - Time.iso8601(previous["booted_at"]) > REBOOT_TOLERANCE
      changes << { kind: :server_rebooted, data: { booted_at: data["booted_at"] } }
    end
    changes
  end

  def self.server_attributes(data)
    { os_name: data["name"], os_id: data["id"], os_version: data["version_id"] }
  end


  # KEY=value lines, values optionally quoted (os-release(5)).
  def self.parse_os_release(text)
    text.to_s.each_line.filter_map do |line|
      key, value = line.strip.split("=", 2)
      next unless value && key.match?(/\A[A-Z_]+\z/)

      [ key, value.delete_prefix('"').delete_suffix('"').delete_prefix("'").delete_suffix("'").gsub('\\"', '"') ]
    end.to_h
  end

  # os-release of a Docker image: the keys Vulnerabilities.target needs.
  def self.release_summary(text)
    release = parse_os_release(text)
    { "id" => release["ID"], "codename" => release["VERSION_CODENAME"].presence || release["UBUNTU_CODENAME"], "version_id" => release["VERSION_ID"],
      "name" => release["PRETTY_NAME"] }.compact_blank
  end

  # "Linux 6.1.0-25-amd64 x86_64"
  def self.parse_uname(text)
    _system, kernel, arch = text.to_s.split
    [ kernel, arch ]
  end
  private_class_method :parse_uname

  # "kvm", "lxc", "docker"…, or "none" on a physical machine.
  def self.parse_virt(text) = text.to_s.strip.presence
  private_class_method :parse_virt
end
