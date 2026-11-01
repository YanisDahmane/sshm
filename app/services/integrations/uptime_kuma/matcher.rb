require "resolv"

# Finds the server a probe watches, by the rules enabled in the extension:
# its host name when it is one of the server's IPs (WireGuard included), the
# host of its URL (also resolved in DNS, optionally), or the server's name in
# the probe's name ("[SRV] FR-UTILS-1"). A manual link always wins.
class Integrations::UptimeKuma::Matcher
  Match = Data.define(:server, :matched_by, :address)

  DNS_TIMEOUT = 2

  def initialize(servers, manual_links: {}, by_ip: true, by_host: true, resolve_dns: false, by_name: true)
    @servers = servers.to_a
    @servers_by_id = @servers.index_by(&:id)
    @manual_links = manual_links
    @rules = { by_ip:, by_host:, resolve_dns:, by_name: }
    @by_address = {}
    @servers.each { |server| server.addresses.each { |address| @by_address[normalize_ip(address)] ||= server } }
    @by_host = {}
    @servers.each do |server|
      [ server.hostname, server.hostname.to_s.split(".").first, (server.host unless Inventory::IpScope.ip?(server.host)) ].compact_blank.each do |name|
        @by_host[name.downcase] ||= server
      end
    end
    @by_name = @servers.flat_map { |server| [ server.name, server.hostname.to_s.split(".").first ].compact_blank.uniq.map { |name| [ name, server ] } }
                       .sort_by { |name, _| -name.length }
    @dns = {}
  end

  # Match or nil (no server).
  def call(monitor)
    if @manual_links.key?(monitor.id.to_s)
      server = @servers_by_id[@manual_links[monitor.id.to_s]]
      return server ? Match.new(server, "manual", nil) : nil
    end

    by_target(monitor.hostname) || by_target(url_host(monitor.url)) || by_monitor_name(monitor.name)
  end

  private

  def by_target(host)
    return if host.blank?

    if Inventory::IpScope.ip?(host)
      return unless @rules[:by_ip]

      server = @by_address[normalize_ip(host)]
      return Match.new(server, "ip", host) if server
    elsif @rules[:by_host]
      server = @by_host[host.downcase]
      return Match.new(server, "url", nil) if server

      if @rules[:resolve_dns]
        resolve(host).each do |address|
          server = @by_address[normalize_ip(address)]
          return Match.new(server, "dns", address) if server
        end
      end
    end
    nil
  end

  def by_monitor_name(name)
    return unless @rules[:by_name] && name.present?

    found = @by_name.find { |candidate, _| name.match?(/(?<![\w-])#{Regexp.escape(candidate)}(?![\w-])/i) }
    Match.new(found.last, "name", nil) if found
  end

  def url_host(url)
    URI.parse(url.to_s).host&.delete_prefix("[")&.delete_suffix("]")
  rescue URI::InvalidURIError
    nil
  end

  def resolve(host)
    @dns[host] ||= Resolv::DNS.open do |dns|
      dns.timeouts = DNS_TIMEOUT
      dns.getaddresses(host).map(&:to_s)
    end
  rescue Resolv::ResolvError, SocketError, SystemCallError
    @dns[host] = []
  end

  def normalize_ip(address) = IPAddr.new(address.to_s).to_s
end
