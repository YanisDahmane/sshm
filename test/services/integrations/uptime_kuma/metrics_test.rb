require "test_helper"

class Integrations::UptimeKuma::MetricsTest < ActiveSupport::TestCase
  test "parses a real Uptime Kuma 2.5 page" do
    result = Integrations::UptimeKuma::Metrics.parse(file_fixture("integrations/uptime_kuma/metrics_v2.txt").read)

    assert_equal "2.5.6", result.version
    assert_equal [ "[INTRANET] Reverse Proxy", "[SRV] [INTRANET] FR-UTILS-1" ], result.monitors.map(&:name)

    proxy, utils = result.monitors
    assert_equal [ "58", "http", "http://rproxy.example.tech/", nil, nil ], [ proxy.id, proxy.monitor_type, proxy.url, proxy.hostname, proxy.port ]
    assert_equal %w[FR INTRANET Prod], proxy.tags
    assert_equal 1, proxy.status
    assert_equal 13.0, proxy.response_time_ms
    assert_equal({ "1d" => 1.0, "30d" => 0.9962562396006656, "365d" => 0.9962562396006656 }, proxy.uptime)
    assert_in_delta 30.74, proxy.average_response_ms["30d"], 0.01

    assert_equal [ "64", "ping", nil, "10.8.0.100" ], [ utils.id, utils.monitor_type, utils.url, utils.hostname ], "a ping probe's https:// is not a target"
    assert_equal %w[FR INTRANET SRV], utils.tags
    assert_nil utils.cert_days_remaining
  end

  test "Uptime Kuma 1.x: certificates, statuses, escaped labels, NaN" do
    text = <<~METRICS
      # HELP monitor_status Monitor Status (1 = UP, 0= DOWN, 2= PENDING, 3= MAINTENANCE)
      monitor_cert_days_remaining{monitor_name="Site \\"public\\"",monitor_type="http",monitor_url="https://www.example.com/",monitor_hostname="null",monitor_port="null",monitor_id="3"} 12
      monitor_cert_is_valid{monitor_name="Site \\"public\\"",monitor_type="http",monitor_url="https://www.example.com/",monitor_hostname="null",monitor_port="null",monitor_id="3"} 1
      monitor_response_time{monitor_name="Site \\"public\\"",monitor_type="http",monitor_url="https://www.example.com/",monitor_hostname="null",monitor_port="null",monitor_id="3"} NaN
      monitor_status{monitor_name="Site \\"public\\"",monitor_type="http",monitor_url="https://www.example.com/",monitor_hostname="null",monitor_port="null",monitor_id="3"} 0
      monitor_status{monitor_name="SSH",monitor_type="port",monitor_url="https://",monitor_hostname="203.0.113.4",monitor_port="22",monitor_id="4"} 3
      process_cpu_seconds_total 12
      garbage line
    METRICS
    result = Integrations::UptimeKuma::Metrics.parse(text)

    assert_nil result.version
    site, ssh = result.monitors
    assert_equal [ "Site \"public\"", 0, 12, true, nil ], [ site.name, site.status, site.cert_days_remaining, site.cert_valid, site.response_time_ms ]
    assert_equal [ "SSH", 3, "203.0.113.4", 22 ], [ ssh.name, ssh.status, ssh.hostname, ssh.port ]
    assert_empty ssh.uptime
  end

  test "an empty or unrelated page" do
    assert_empty Integrations::UptimeKuma::Metrics.parse("").monitors
    assert_empty Integrations::UptimeKuma::Metrics.parse("<html>login</html>").monitors
  end
end
