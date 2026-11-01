require "ipaddr"

# Attaches OVHcloud resources to the servers: a manual link first, then by
# address (an IP block containing an address of the server), by the service
# an IP block is routed to, by name (service reverse / name = host name or
# server name), and DNS CNAME records by the record or host they point to.
class Integrations::Ovh::Matcher
  Match = Data.define(:server, :matched_by, :address)

  def initialize(servers, manual_links: {})
    @servers = servers.to_a
    @by_id = @servers.index_by(&:id)
    @manual_links = manual_links
    @addresses = @servers.flat_map { |server| server.addresses.filter_map { |address| [ ip(address), address, server ] if ip(address) } }
    @by_name = {}
    @servers.each do |server|
      [ server.name, server.hostname, server.hostname.to_s.split(".").first, (server.host unless Inventory::IpScope.ip?(server.host)) ].compact_blank.each do |name|
        @by_name[name.downcase] ||= server
      end
    end
  end

  # { resource (Fetch::Resource) => Match or nil }
  def call(resources)
    matches = {}
    services = {}
    ordered = resources.sort_by { |resource| %w[dedicated vps instance ip dns_record].index(resource.kind) || 9 }
    ordered.each do |resource|
      match = manual(resource) || by_address(resource) || by_service(resource, services) || by_name(resource)
      matches[resource] = match == :none ? nil : match
      services[resource.data["service"] || resource.external_id] = matches[resource] if resource.kind.in?(%w[dedicated vps])
    end
    by_fqdn = resources.select { |resource| resource.kind == "dns_record" }.to_h { |resource| [ resource.name.downcase, matches[resource] ] }
    resources.each do |resource|
      next unless resource.kind == "dns_record" && resource.data["type"] == "CNAME" && matches[resource].nil? && !@manual_links.key?(key(resource))

      target = resource.data["target"].to_s.downcase
      server = by_fqdn[target]&.server || @by_name[target] || @by_name[target.split(".").first]
      matches[resource] = Match.new(server, "cname", nil) if server
    end
    matches
  end

  private

  def key(resource) = "#{resource.kind}:#{resource.external_id}"

  def manual(resource)
    return unless @manual_links.key?(key(resource))

    server = @by_id[@manual_links[key(resource)]]
    server ? Match.new(server, "manual", nil) : :none
  end

  def by_address(resource)
    resource.addresses.each do |value|
      network = ip(value) or next
      found = @addresses.find { |address, _, _| network.include?(address) }
      return Match.new(found.last, "address", found[1]) if found
    end
    nil
  end

  def by_service(resource, services)
    return unless resource.kind == "ip" && resource.data["service"]

    match = services[resource.data["service"]]
    Match.new(match.server, "service", nil) if match
  end

  def by_name(resource)
    return unless resource.kind.in?(%w[dedicated vps instance])

    [ resource.name, resource.data["reverse"], resource.external_id ].compact_blank.each do |name|
      server = @by_name[name.downcase] || @by_name[name.downcase.split(".").first]
      return Match.new(server, "name", nil) if server
    end
    nil
  end

  def ip(value)
    IPAddr.new(value.to_s)
  rescue IPAddr::InvalidAddressError, IPAddr::AddressFamilyError
    nil
  end
end
