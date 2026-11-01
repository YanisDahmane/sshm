require "ipaddr"

# Finds the server an external resource belongs to (Uptime Kuma probe, OVH
# IP, DNS record…): by one of its addresses (collected, added by hand, SSH
# host), by a network containing one of them, by host name, or by its name
# inside a text. Built once for a whole synchronization.
class ServerDirectory
  Found = Data.define(:server, :address)

  attr_reader :servers

  def initialize(servers)
    @servers = servers.to_a
    @addresses = @servers.flat_map { |server| server.addresses.filter_map { |address| (ip = self.class.ip(address)) && [ ip, address, server ] } }
    @hosts = {}
    @servers.each do |server|
      [ server.hostname, short(server.hostname), (server.host unless Inventory::IpScope.ip?(server.host)) ].compact_blank.each { |host| @hosts[host.downcase] ||= server }
    end
    @names = @servers.flat_map { |server| [ server.name, short(server.hostname) ].compact_blank.uniq.map { |name| [ name, server ] } }.sort_by { |name, _| -name.length }
  end

  # The server with this address (IPv6 written any way), or a network
  # ("203.0.113.0/24", "2001:db8::/64") containing one of its addresses.
  def by_address(value)
    network = self.class.ip(value) or return
    found = @addresses.find { |ip, _, _| network.include?(ip) }
    Found.new(found.last, found[1]) if found
  end

  # The server whose host name (full or short) or SSH host name is `host`;
  # with `names`, its name in Elio counts too.
  def by_host(host, names: false)
    return if host.blank?

    host = host.to_s.downcase
    @hosts[host] || @hosts[short(host)] || (names ? @servers.find { |server| server.name.casecmp?(host) || server.name.casecmp?(short(host)) } : nil)
  end

  # The server whose name (or short host name) appears as a whole word in
  # `text` ("[SRV] FR-UTILS-1"), the longest name first ("Web-2" before "Web").
  def named_in(text)
    return if text.blank?

    @names.find { |name, _| text.match?(/(?<![\w-])#{Regexp.escape(name)}(?![\w-])/i) }&.last
  end

  def self.ip(value)
    IPAddr.new(value.to_s)
  rescue IPAddr::InvalidAddressError, IPAddr::AddressFamilyError
    nil
  end

  private

  def short(name) = name.to_s.split(".").first
end
