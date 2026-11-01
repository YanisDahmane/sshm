require "ipaddr"

# Listening ports of a server (ss) with the process and systemd unit behind
# each one, and the firewall state (ufw, otherwise nftables or iptables).
# Processes of other users and the firewall need root: without it the
# collection is partial. Elio never changes the firewall.
class Inventory::Collectors::Ports < Inventory::Collector
  # Ports of the usual ufw application profiles.
  UFW_APPS = { "OpenSSH" => [ "22/tcp" ], "Nginx HTTP" => [ "80/tcp" ], "Nginx HTTPS" => [ "443/tcp" ], "Nginx Full" => [ "80/tcp", "443/tcp" ],
               "Apache" => [ "80/tcp" ], "Apache Secure" => [ "443/tcp" ], "Apache Full" => [ "80/tcp", "443/tcp" ], "Postfix" => [ "25/tcp" ] }.freeze

  def collect
    result = run("inventory.ports")
    raise Error, "Lecture des ports impossible : #{result.stderr.strip.presence || "code #{result.exit_status}"}" if result.stdout.blank?

    sections = result.stdout.split(/^@@elio (\S+)\n/).drop(1).each_slice(2).to_h { |name, body| [ name, body.to_s ] }
    return unsupported("La commande ss n'est pas disponible") if sections["ss"].to_s.strip == "unsupported"

    data = self.class.parse(sections)
    privileged? ? ok(data) : partial(data, "Sans accès root : processus des autres utilisateurs et firewall inconnus")
  end

  def self.parse(sections)
    units = parse_cgroups(sections["cgroups"].to_s)
    { "listening" => parse_ss(sections["ss"].to_s, units), "firewall" => parse_firewall(sections) }
  end

  # "tcp LISTEN 0 4096 0.0.0.0:22 0.0.0.0:* users:(("sshd",pid=812,fd=3))"
  def self.parse_ss(text, units = {})
    text.lines.filter_map do |line|
      proto, _state, _recv, _send, local, _peer, *process = line.split
      next unless proto && local && %w[tcp udp].include?(proto)

      address, port = split_address(local)
      next unless port&.match?(/\A\d+\z/)

      name = process.join(" ")[/\(\("([^"]+)"/, 1]
      pid = process.join(" ")[/pid=(\d+)/, 1]
      { "proto" => proto, "address" => address, "port" => port.to_i, "scope" => scope(address),
        "process" => name, "pid" => pid&.to_i, "unit" => (units[pid] if pid) }.compact
    end.uniq { |entry| entry.values_at("proto", "address", "port") }.sort_by { |entry| [ entry["port"], entry["proto"], entry["address"] ] }
  end

  # "812 0::/system.slice/ssh.service" → { "812" => "ssh.service" }
  def self.parse_cgroups(text)
    text.lines.filter_map do |line|
      pid, cgroup = line.strip.split(" ", 2)
      unit = cgroup.to_s.split("/").reverse.find { |part| part.end_with?(".service", ".scope") }
      [ pid, unit ] if pid && unit
    end.to_h
  end

  # "0.0.0.0:22", "[::]:22", "*:22", "127.0.0.53%lo:53", "[::ffff:127.0.0.1]:6379"
  def self.split_address(local)
    address, _, port = local.rpartition(":")
    address = address.delete_prefix("[").delete_suffix("]").sub(/%.*\z/, "")
    address = address.delete_prefix("::ffff:") if address.start_with?("::ffff:") && address.count(".") == 3
    [ address, port ]
  end

  # public (every interface or a public address), private (LAN, VPN) or local (loopback).
  def self.scope(address) = Inventory::IpScope.of(address)

  def self.parse_firewall(sections)
    ufw = sections["ufw"].to_s
    nft = sections["nft"].to_s
    iptables = sections["iptables"].to_s
    unreadable = ->(text) { text.match?(/permission denied|need to be root|must be root|Operation not permitted/i) }

    if ufw.match?(/^Status: active/)
      parse_ufw(ufw)
    elsif !nft.strip.start_with?("absent") && !unreadable.(nft) && nft.include?("hook input")
      parse_nft(nft)
    elsif !iptables.strip.start_with?("absent") && !unreadable.(iptables) && iptables.include?("-P INPUT")
      parse_iptables(iptables)
    elsif [ ufw, nft, iptables ].any? { |text| unreadable.(text) }
      { "tool" => "unknown", "active" => nil }
    else
      { "tool" => (ufw.include?("inactive") ? "ufw" : "none"), "active" => false }
    end
  end

  # ufw status verbose: "Default: deny (incoming), …" then "To  Action  From" rules.
  def self.parse_ufw(text)
    default = text[/^Default:\s*(\w+) \(incoming\)/, 1]
    allowed = text.lines.flat_map do |line|
      match = line.match(/\A(?<to>.+?)\s+(?<action>ALLOW|LIMIT)(?: IN)?\s+(?<from>.+?)\s*\z/)
      next [] unless match && !match[:to].start_with?("To")

      to = match[:to].sub(/\s*\(v6\)\z/, "").strip
      from = match[:from].sub(/\s*\(v6\)\z/, "").strip
      targets = UFW_APPS.fetch(to) { [ to.split.first ] }
      targets.map { |target| { "rule" => target, "from" => (from == "Anywhere" ? nil : from) }.compact }
    end
    { "tool" => "ufw", "active" => true, "default_incoming" => default, "allowed" => allowed.uniq }
  end

  # An nftables input chain that accepts everything without any rule filters nothing.
  def self.parse_nft(text)
    input = text[/chain input \{.*?\n\s*\}/m].to_s
    policy = input[/policy (\w+);/, 1]
    rules = input.lines.count { |line| line.match?(/\b(accept|drop|reject)\b/) && !line.include?("policy") }
    return { "tool" => "none", "active" => false } if policy != "drop" && rules.zero?

    allowed = input.scan(/(tcp|udp) dport (\{[^}]+\}|\d+(?:-\d+)?) .*?accept/).flat_map do |proto, ports|
      ports.delete("{} ").split(",").map { |port| { "rule" => "#{port.tr("-", ":")}/#{proto}" } }
    end
    { "tool" => "nftables", "active" => true, "default_incoming" => (policy == "drop" ? "deny" : policy), "allowed" => allowed.uniq }
  end

  # "-P INPUT ACCEPT" without any "-A INPUT" rule (the Debian default) filters nothing.
  def self.parse_iptables(text)
    policy = text[/^-P INPUT (\w+)/, 1]
    return { "tool" => "none", "active" => false } if policy == "ACCEPT" && text.lines.none? { |line| line.start_with?("-A INPUT") }

    allowed = text.lines.filter_map do |line|
      next unless line.include?("-j ACCEPT") && (port = line[/--dports? (\S+)/, 1])

      { "rule" => "#{port}/#{line[/-p (\w+)/, 1] || "tcp"}", "from" => line[/-s (\S+)/, 1] }.compact
    end
    { "tool" => "iptables", "active" => true, "default_incoming" => ({ "DROP" => "deny", "REJECT" => "deny" }[policy] || policy&.downcase), "allowed" => allowed.uniq }
  end

  # Public ports that appeared or disappeared (by port and protocol).
  def self.changes(previous, data)
    public_ports = ->(entries) { Array(entries).select { |entry| entry["scope"] == "public" }.map { |entry| "#{entry["port"]}/#{entry["proto"]}" }.to_set }
    processes = Array(data["listening"]).to_h { |entry| [ "#{entry["port"]}/#{entry["proto"]}", entry["process"] ] }
    before = public_ports.(previous["listening"])
    after = public_ports.(data["listening"])

    (after - before).sort.map { |port| { kind: :port_opened, data: { port: port, process: processes[port] }.compact } } +
      (before - after).sort.map { |port| { kind: :port_closed, data: { port: port } } }
  end
end
