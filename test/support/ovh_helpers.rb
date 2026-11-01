# OVHcloud extension in tests: a fake API (routes → JSON) instead of the
# network, with a realistic account. Requests are recorded with their headers.
module OvhHelpers
  OVH_BASE = "https://eu.api.ovh.com/1.0"

  def enable_ovh(**settings)
    Integration.find_or_initialize_by(kind: "ovh").tap do |integration|
      integration.update!(enabled: true, settings: { "application_key" => "app-key" }.merge(settings.stringify_keys),
                          secrets: { "application_secret" => "app-secret", "consumer_key" => "consumer-key" })
    end
  end

  def ovh_account(expiration: 10.days.from_now.to_date, renew_automatic: false)
    {
      "/auth/currentCredential" => { "status" => "validated", "rules" => %w[/auth/currentCredential /ip /ip/* /domain/zone /domain/zone/* /dedicated/server /dedicated/server/* /vps /vps/* /cloud/project /cloud/project/*].map { { "method" => "GET", "path" => _1 } } },
      "/ip" => [ "203.0.113.10/32", "198.51.100.7/32" ],
      "/ip/203.0.113.10%2F32" => { "ip" => "203.0.113.10/32", "type" => "dedicated", "routedTo" => { "serviceName" => "ns1234.ip-203-0-113.eu" } },
      "/ip/203.0.113.10%2F32/reverse" => [ "203.0.113.10" ],
      "/ip/203.0.113.10%2F32/reverse/203.0.113.10" => { "reverse" => "web.example.com." },
      "/ip/203.0.113.10%2F32/firewall" => [ "203.0.113.10" ],
      "/ip/203.0.113.10%2F32/firewall/203.0.113.10" => { "enabled" => true, "state" => "ok" },
      "/ip/203.0.113.10%2F32/firewall/203.0.113.10/rule" => [ 19, 0, 1 ],
      "/ip/203.0.113.10%2F32/firewall/203.0.113.10/rule/0" => { "sequence" => 0, "action" => "permit", "protocol" => "tcp", "destinationPort" => "eq 22", "source" => "192.0.2.0/24" },
      "/ip/203.0.113.10%2F32/firewall/203.0.113.10/rule/1" => { "sequence" => 1, "action" => "permit", "protocol" => "tcp", "destinationPort" => "eq 443" },
      "/ip/203.0.113.10%2F32/firewall/203.0.113.10/rule/19" => { "sequence" => 19, "action" => "deny", "protocol" => "ipv4" },
      "/ip/203.0.113.10%2F32/mitigation" => [ "203.0.113.10" ],
      "/ip/203.0.113.10%2F32/mitigation/203.0.113.10" => { "permanent" => false, "auto" => true, "state" => "ok" },
      "/ip/198.51.100.7%2F32" => { "ip" => "198.51.100.7/32", "type" => "failover" },
      "/ip/198.51.100.7%2F32/reverse" => [],
      "/ip/198.51.100.7%2F32/firewall" => [],
      "/ip/198.51.100.7%2F32/mitigation" => [],
      "/domain/zone" => [ "example.com" ],
      "/domain/zone/example.com/record?fieldType=A" => [ 1, 2 ],
      "/domain/zone/example.com/record?fieldType=AAAA" => [],
      "/domain/zone/example.com/record?fieldType=CNAME" => [ 3 ],
      "/domain/zone/example.com/record/1" => { "fieldType" => "A", "subDomain" => "www", "target" => "203.0.113.10", "ttl" => 3600, "zone" => "example.com" },
      "/domain/zone/example.com/record/2" => { "fieldType" => "A", "subDomain" => "old", "target" => "192.0.2.99", "ttl" => 0, "zone" => "example.com" },
      "/domain/zone/example.com/record/3" => { "fieldType" => "CNAME", "subDomain" => "app", "target" => "www.example.com.", "ttl" => 0, "zone" => "example.com" },
      "/dedicated/server" => [ "ns1234.ip-203-0-113.eu" ],
      "/dedicated/server/ns1234.ip-203-0-113.eu" => { "name" => "ns1234.ip-203-0-113.eu", "ip" => "203.0.113.10", "reverse" => "web.example.com.", "datacenter" => "gra3",
                                                     "commercialRange" => "Advance-1", "state" => "ok", "os" => "debian12_64" },
      "/dedicated/server/ns1234.ip-203-0-113.eu/serviceInfos" => { "expiration" => expiration.iso8601, "renew" => { "automatic" => renew_automatic }, "status" => "ok" },
      "/dedicated/server/ns1234.ip-203-0-113.eu/ips" => [ "203.0.113.10/32" ],
      "/vps" => [ "vps-abc123.vps.ovh.net" ],
      "/vps/vps-abc123.vps.ovh.net" => { "name" => "vps-abc123.vps.ovh.net", "displayName" => "Staging", "zone" => "Region OpenStack: os-gra7", "state" => "running",
                                         "model" => { "name" => "vps-value-1-2-40" } },
      "/vps/vps-abc123.vps.ovh.net/serviceInfos" => { "expiration" => 200.days.from_now.to_date.iso8601, "renew" => { "automatic" => true } },
      "/vps/vps-abc123.vps.ovh.net/ips" => [ "198.51.100.20" ],
      "/cloud/project" => [ "p1" ],
      "/cloud/project/p1" => { "description" => "Production" },
      "/cloud/project/p1/instance" => [ { "id" => "i-1", "name" => "Database", "status" => "ACTIVE", "region" => "GRA11", "flavorId" => "b3-8",
                                          "ipAddresses" => [ { "ip" => "10.1.2.3", "type" => "private", "version" => 4 }, { "ip" => "192.0.2.50", "type" => "public", "version" => 4 } ] } ]
    }
  end

  def fake_ovh(routes = ovh_account)
    @ovh_requests = []
    stub_method_until_teardown(Integrations::Http, :get, lambda { |url, service:, headers: {}, **|
      @ovh_requests << [ url, headers ]
      path = url.delete_prefix(OVH_BASE)
      next Time.now.to_i.to_s if path == "/auth/time"
      raise Integrations::Error, "#{service} a répondu 404 : #{path}" unless routes.key?(path)

      routes.fetch(path).to_json
    })
  end
end
