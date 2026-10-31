require "test_helper"

class Inventory::Collectors::PortsTest < ActiveSupport::TestCase
  Collector = Inventory::Collectors::Ports

  def sections(name) = file_fixture("inventory/ports/#{name}.txt").read.split(/^@@elio (\S+)\n/).drop(1).each_slice(2).to_h

  def parse(name) = Collector.parse(sections(name))

  test "parses the listening ports with their process, unit and scope" do
    listening = parse(:debian12)["listening"]

    assert_equal [ [ 22, "tcp", "0.0.0.0" ], [ 22, "tcp", "::" ], [ 53, "udp", "127.0.0.53" ], [ 3306, "tcp", "127.0.0.1" ], [ 5050, "tcp", "127.0.0.1" ],
                   [ 5432, "tcp", "10.0.1.20" ], [ 6432, "tcp", "0.0.0.0" ], [ 9100, "tcp", "*" ], [ 41_641, "udp", "100.64.0.12" ] ],
                 listening.map { |entry| entry.values_at("port", "proto", "address") }
    assert_equal({ "proto" => "tcp", "address" => "0.0.0.0", "port" => 22, "scope" => "public", "process" => "sshd", "pid" => 812, "unit" => "ssh.service" }, listening.first)
    assert_equal %w[local private], listening.select { |entry| [ 53, 5432 ].include?(entry["port"]) }.map { |entry| entry["scope"] }
    assert_equal "postgresql@15-main.service", listening.find { |entry| entry["port"] == 5432 }["unit"]
    assert_equal "private", listening.last["scope"]
  end

  test "classifies the listening addresses" do
    { "0.0.0.0" => "public", "::" => "public", "*" => "public", "51.38.12.4" => "public", "2001:db8::1" => "public",
      "127.0.0.1" => "local", "::1" => "local", "10.2.3.4" => "private", "192.168.1.1" => "private", "172.20.0.1" => "private",
      "fd12::1" => "private", "fe80::1" => "private", "not-an-ip" => "public" }.each do |address, scope|
      assert_equal scope, Collector.scope(address), address
    end
    assert_equal [ "127.0.0.1", "6379" ], Collector.split_address("[::ffff:127.0.0.1]:6379")
  end

  test "reads an active ufw: default policy, rules, application profiles and sources" do
    assert_equal({ "tool" => "ufw", "active" => true, "default_incoming" => "deny",
                   "allowed" => [ { "rule" => "22/tcp" }, { "rule" => "80/tcp" }, { "rule" => "443/tcp" }, { "rule" => "5432", "from" => "10.0.0.0/16" } ] },
                 parse(:debian12)["firewall"])
  end

  test "reads nftables and iptables when ufw is not active" do
    assert_equal({ "tool" => "nftables", "active" => true, "default_incoming" => "deny",
                   "allowed" => [ { "rule" => "22/tcp" }, { "rule" => "80/tcp" }, { "rule" => "443/tcp" }, { "rule" => "51820/udp" } ] }, parse(:nft)["firewall"])
    assert_equal({ "tool" => "iptables", "active" => true, "default_incoming" => "deny",
                   "allowed" => [ { "rule" => "22/tcp" }, { "rule" => "80,443/tcp", "from" => "10.0.0.0/8" } ] }, parse(:iptables)["firewall"])
  end

  test "without root, processes and firewall are unknown" do
    data = parse(:no_root)

    assert_equal [ [ 22, nil ], [ 80, nil ] ], data["listening"].select { |entry| entry["address"] == "0.0.0.0" }.map { |entry| entry.values_at("port", "process") }
    assert_equal({ "tool" => "unknown", "active" => nil }, data["firewall"])
  end

  test "no firewall at all" do
    assert_equal({ "tool" => "none", "active" => false }, Collector.parse_firewall("ufw" => "absent\n", "nft" => "absent\n", "iptables" => "absent\n"))
  end

  test "collects through sudo, partial without root" do
    output = file_fixture("inventory/ports/debian12.txt").read
    [ [ true, "ok" ], [ false, "partial" ] ].each do |sudo, status|
      known_hosts = Rails.root.join("tmp", "test", "ports-#{SecureRandom.hex(4)}", "known_hosts")
      fake = FakeSsh.new(responses: { "sudo -n true" => FakeSsh::Response.new("", "", sudo ? 0 : 1) },
                         handler: ->(command) { FakeSsh::Response.new(output, "", 0) if command.include?("sh -c") })
      outcome = SshConnection.open(servers(:web), transport: fake, known_hosts_file: known_hosts) { |ssh| Collector.new(ssh).collect }
      assert_equal status, outcome.status
      assert_equal sudo, fake.commands.last.start_with?("sudo -n sh -c")
      FileUtils.rm_rf(known_hosts.dirname)
    end
  end

  test "logs the public ports that open or close" do
    previous = { "listening" => [ { "port" => 22, "proto" => "tcp", "scope" => "public" }, { "port" => 8080, "proto" => "tcp", "scope" => "public" } ] }
    data = { "listening" => [ { "port" => 22, "proto" => "tcp", "scope" => "public" }, { "port" => 3306, "proto" => "tcp", "scope" => "public", "process" => "mariadbd" },
                              { "port" => 6379, "proto" => "tcp", "scope" => "local" } ] }

    assert_equal [ { kind: :port_opened, data: { port: "3306/tcp", process: "mariadbd" } }, { kind: :port_closed, data: { port: "8080/tcp" } } ],
                 Collector.changes(previous, data)
  end
end
