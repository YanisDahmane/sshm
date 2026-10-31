require "test_helper"

class Inventory::Collectors::OsTest < ActiveSupport::TestCase
  NOW = Time.utc(2026, 10, 31, 12, 0, 0)

  def output(name) = file_fixture("inventory/os/#{name}.txt").read

  def parse(name) = Inventory::Collectors::Os.parse(output(name), now: NOW)

  test "parses Debian 12" do
    assert_equal({
      "name" => "Debian GNU/Linux 12 (bookworm)", "id" => "debian", "version_id" => "12", "codename" => "bookworm",
      "kernel" => "6.1.0-25-amd64", "arch" => "x86_64", "hostname" => "db-prod.acme.internal", "virtualization" => "kvm",
      "booted_at" => "2026-09-20T12:00:00Z", "cpus" => 8, "memory_bytes" => 32_858_112 * 1024, "timezone" => "Europe/Paris"
    }, parse(:debian12))
  end

  test "parses Ubuntu 24.04 and 22.04, with the Ubuntu codename and the family" do
    noble = parse(:ubuntu2404)
    assert_equal [ "Ubuntu 24.04.1 LTS", "ubuntu", "debian", "24.04", "noble", "aarch64", "none", 4, "Etc/UTC" ],
                 noble.values_at("name", "id", "id_like", "version_id", "codename", "arch", "virtualization", "cpus", "timezone")
    assert_equal "2026-10-30T12:00:00Z", noble["booted_at"]

    jammy = parse(:ubuntu2204)
    assert_equal [ "Ubuntu 22.04.5 LTS", "22.04", "jammy", "lxc", "5.15.0-122-generic" ], jammy.values_at("name", "version_id", "codename", "virtualization", "kernel")
    assert_not jammy.key?("timezone")
  end

  test "keeps what it can from a minimal system" do
    data = parse(:minimal)

    assert_equal [ "Alpine Linux", "alpine", "3.20.3", 1 ], data.values_at("name", "id", "version_id", "cpus")
    assert_not data.key?("booted_at")
    assert_not data.key?("memory_bytes")
    assert_not data.key?("virtualization")
  end

  test "an empty os-release still gives a name" do
    assert_equal "Inconnu", Inventory::Collectors::Os.parse("@@elio uname\nLinux 6.1 x86_64\n")["name"]
  end

  test "collects with one command and reports an unreadable system" do
    collected = run_collector(FakeSsh::Response.new(output(:debian12), "", 0))
    assert_equal [ "ok", "debian" ], [ collected.status, collected.data["id"] ]

    error = assert_raises(Inventory::Collector::Error) { run_collector(FakeSsh::Response.new("", "sh: not found\n", 127)) }
    assert_equal "Lecture du système impossible : sh: not found", error.message
  end

  test "logs an upgrade and a reboot" do
    previous = parse(:ubuntu2204).merge("booted_at" => "2026-10-01T08:00:00Z")
    upgraded = previous.merge("name" => "Ubuntu 24.04.1 LTS", "version_id" => "24.04", "booted_at" => "2026-10-31T09:00:00Z")

    assert_equal [ { kind: :os_upgraded, data: { from: "Ubuntu 22.04.5 LTS", to: "Ubuntu 24.04.1 LTS" } },
                   { kind: :server_rebooted, data: { booted_at: "2026-10-31T09:00:00Z" } } ],
                 Inventory::Collectors::Os.changes(previous, upgraded)
  end

  test "a boot time that moves by seconds is the same boot" do
    previous = { "version_id" => "12", "booted_at" => "2026-10-01T08:00:00Z" }

    assert_empty Inventory::Collectors::Os.changes(previous, previous.merge("booted_at" => "2026-10-01T08:00:02Z"))
    assert_empty Inventory::Collectors::Os.changes({}, previous)
  end

  test "summarises the system on the server" do
    assert_equal({ os_name: "Debian GNU/Linux 12 (bookworm)", os_id: "debian", os_version: "12" },
                 Inventory::Collectors::Os.server_attributes(parse(:debian12)))
  end

  private

  def run_collector(response)
    known_hosts = Rails.root.join("tmp", "test", "os-#{SecureRandom.hex(4)}", "known_hosts")
    fake = FakeSsh.new(handler: ->(command) { response if command.start_with?("sh -c") })
    SshConnection.open(servers(:web), transport: fake, known_hosts_file: known_hosts) { |ssh| Inventory::Collectors::Os.new(ssh).collect }
  ensure
    FileUtils.rm_rf(known_hosts.dirname)
  end
end
