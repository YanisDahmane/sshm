# Reads the OVHcloud resources chosen in the extension (GET only) into plain
# Resource values: IP blocks (reverse, network firewall, anti-DDoS), DNS
# records (A, AAAA, CNAME), dedicated servers, VPS and Public Cloud instances.
class Integrations::Ovh::Fetch
  Resource = Data.define(:kind, :external_id, :name, :data, :addresses, :expires_at)

  PRODUCTS = %w[ip firewall mitigation dns dedicated vps cloud].freeze # labels: integrations.ovh.product_labels.*

  # API rights needed by each product (all read-only).
  RIGHTS = { "ip" => %w[/ip /ip/*], "firewall" => %w[/ip /ip/*], "mitigation" => %w[/ip /ip/*], "dns" => %w[/domain/zone /domain/zone/*],
             "dedicated" => %w[/dedicated/server /dedicated/server/*], "vps" => %w[/vps /vps/*], "cloud" => %w[/cloud/project /cloud/project/*] }.freeze
  BASE_RIGHTS = %w[/auth/currentCredential].freeze
  RECORD_TYPES = %w[A AAAA CNAME].freeze

  def self.rights(products) = (BASE_RIGHTS + Array(products).flat_map { |product| RIGHTS.fetch(product, []) }).uniq

  def initialize(client, products:, zones: [], projects: [])
    @client = client
    @products = Array(products)
    @zones = Array(zones)
    @projects = Array(projects)
  end

  def call
    [ *(ips if wants_ip?), *(dns_records if @products.include?("dns")), *(dedicated_servers if @products.include?("dedicated")),
      *(vps if @products.include?("vps")), *(cloud_instances if @products.include?("cloud")) ]
  end

  private

  def wants_ip? = (@products & %w[ip firewall mitigation]).any?

  def get(path) = @client.get(path)
  def seg(value) = Integrations::Ovh::Client.segment(value)

  def ips
    each_parallel(get("/ip")) do |block|
      info = get("/ip/#{seg(block)}")
      data = { "block" => block, "type" => info["type"], "service" => info.dig("routedTo", "serviceName"), "description" => info["description"],
               "country" => info["country"] }.compact
      data["reverse"] = reverses(block) if @products.include?("ip")
      data["firewall"] = firewalls(block) if @products.include?("firewall")
      data["mitigation"] = mitigations(block) if @products.include?("mitigation")
      Resource.new(kind: "ip", external_id: block, name: block, data: data, addresses: [ block ], expires_at: nil)
    end
  end

  def reverses(block)
    get("/ip/#{seg(block)}/reverse").to_h { |ip| [ ip, get("/ip/#{seg(block)}/reverse/#{seg(ip)}")["reverse"].to_s.delete_suffix(".") ] }
  rescue Integrations::Error
    {}
  end

  def firewalls(block)
    get("/ip/#{seg(block)}/firewall").to_h do |ip|
      state = get("/ip/#{seg(block)}/firewall/#{seg(ip)}")
      rules = get("/ip/#{seg(block)}/firewall/#{seg(ip)}/rule").sort.map do |sequence|
        get("/ip/#{seg(block)}/firewall/#{seg(ip)}/rule/#{sequence}")
          .slice("sequence", "action", "protocol", "source", "destinationPort", "sourcePort", "tcpOption", "fragments", "state")
      end
      [ ip, { "enabled" => state["enabled"], "state" => state["state"], "rules" => rules } ]
    end
  rescue Integrations::Error
    {}
  end

  def mitigations(block)
    get("/ip/#{seg(block)}/mitigation").to_h do |ip|
      [ ip, get("/ip/#{seg(block)}/mitigation/#{seg(ip)}").slice("permanent", "auto", "state") ]
    end
  rescue Integrations::Error
    {}
  end

  def dns_records
    zones = get("/domain/zone")
    zones &= @zones if @zones.any?
    zones.flat_map do |zone|
      ids = RECORD_TYPES.flat_map { |type| get("/domain/zone/#{seg(zone)}/record?fieldType=#{type}") }
      each_parallel(ids) do |id|
        record = get("/domain/zone/#{seg(zone)}/record/#{id}")
        fqdn = [ record["subDomain"].presence, zone ].compact.join(".")
        target = record["target"].to_s.strip.delete_suffix(".")
        Resource.new(kind: "dns_record", external_id: "#{zone}/#{id}", name: fqdn,
                     data: { "zone" => zone, "sub_domain" => record["subDomain"].to_s, "type" => record["fieldType"], "target" => target, "ttl" => record["ttl"] },
                     addresses: (%w[A AAAA].include?(record["fieldType"]) ? [ target ] : []), expires_at: nil)
      end
    end
  end

  def dedicated_servers
    each_parallel(get("/dedicated/server")) do |name|
      info = get("/dedicated/server/#{seg(name)}")
      service = service_infos("/dedicated/server/#{seg(name)}")
      addresses = safe_list("/dedicated/server/#{seg(name)}/ips")
      Resource.new(kind: "dedicated", external_id: name, name: info["reverse"].presence&.delete_suffix(".") || name,
                   data: { "service" => name, "offer" => info["commercialRange"], "datacenter" => info["datacenter"], "state" => info["state"],
                           "os" => info["os"], "ip" => info["ip"], "reverse" => info["reverse"]&.delete_suffix(".") }.merge(service).compact,
                   addresses: ([ info["ip"] ] + addresses).compact.uniq, expires_at: parse_date(service["expiration"]))
    end
  end

  def vps
    each_parallel(get("/vps")) do |name|
      info = get("/vps/#{seg(name)}")
      service = service_infos("/vps/#{seg(name)}")
      Resource.new(kind: "vps", external_id: name, name: info["displayName"].presence || name,
                   data: { "service" => name, "offer" => info.dig("model", "name") || info["offerType"], "datacenter" => info["zone"], "state" => info["state"],
                           "cores" => info["vcore"], "memory_mb" => info["memoryLimit"] }.merge(service).compact,
                   addresses: safe_list("/vps/#{seg(name)}/ips"), expires_at: parse_date(service["expiration"]))
    end
  end

  def cloud_instances
    projects = get("/cloud/project")
    projects &= @projects if @projects.any?
    projects.flat_map do |project|
      description = get("/cloud/project/#{seg(project)}")["description"]
      get("/cloud/project/#{seg(project)}/instance").map do |instance|
        addresses = Array(instance["ipAddresses"]).map { |address| address["ip"] }.compact.uniq
        Resource.new(kind: "instance", external_id: "#{project}/#{instance["id"]}", name: instance["name"],
                     data: { "project" => project, "project_name" => description, "region" => instance["region"], "state" => instance["status"],
                             "offer" => instance.dig("flavor", "name") || instance["flavorId"],
                             "networks" => Array(instance["ipAddresses"]).map { |address| address.slice("ip", "type", "version") } }.compact,
                     addresses: addresses, expires_at: nil)
      end
    end
  end

  def service_infos(path)
    info = get("#{path}/serviceInfos")
    { "expiration" => info["expiration"], "renew_automatic" => info.dig("renew", "automatic"), "status" => info["status"] }.compact
  rescue Integrations::Error
    {}
  end

  def safe_list(path)
    get(path)
  rescue Integrations::Error
    []
  end

  def parse_date(value)
    Date.parse(value.to_s) if value.present?
  rescue Date::Error
    nil
  end

  def each_parallel(items, &block) = BoundedParallel.map(Array(items), &block)
end
