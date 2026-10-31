require "test_helper"

class Inventory::Collectors::HealthTest < ActiveSupport::TestCase
  def parse(name) = Inventory::Collectors::Health.parse(file_fixture("inventory/health/#{name}.txt").read)

  test "parses a loaded Debian server" do
    data = parse(:debian12)

    assert_equal [ [ 1.92, 1.75, 1.6 ], 8, 24.0 ], data.values_at("load", "cpus", "load_percent")
    assert_equal({ "total" => 32_858_112 * 1024, "available" => 3_942_973 * 1024, "used_percent" => 88.0 }, data["memory"])
    assert_equal 25.0, data.dig("swap", "used_percent")
    assert_equal %w[/ /boot/efi /var/lib/postgresql], data["disks"].map { |disk| disk["mount"] }
    root = data["disks"].first
    assert_equal [ "ext4", 94.4, 1.3, 503_842_392 * 1024 ], root.values_at("type", "used_percent", "inodes_used_percent", "size")
    assert_not data["disks"].second.key?("inodes_used_percent")
    assert_equal 94.4, data["disk_max_percent"]
    assert_equal [ false, [ "fail2ban.service" ], { "total" => 4, "security" => 3 }, true ],
                 data.values_at("reboot_required", "failed_units", "updates", "ntp_synchronized")
  end

  test "parses an Ubuntu server: mount points with spaces, no swap, reboot required, clock not synchronized" do
    data = parse(:ubuntu2404)

    assert_equal [ "/", "/mnt/backup disk" ], data["disks"].map { |disk| disk["mount"] }
    assert_equal [ 47.8, 92.0 ], data["disks"].first.values_at("used_percent", "inodes_used_percent")
    assert_equal 95.9, data["disk_max_percent"]
    assert_nil data["swap"]
    assert_equal [ true, [], { "total" => 0, "security" => 0 }, false ], data.values_at("reboot_required", "failed_units", "updates", "ntp_synchronized")
  end

  test "keeps what it can from a minimal system without apt" do
    data = parse(:minimal)

    assert_equal [ 0.0, 0.0 ], data.values_at("load_percent", "memory").then { |load, memory| [ load, memory["used_percent"] ] }
    assert_equal [], data["disks"]
    assert_not data.key?("updates")
    assert_not data.key?("ntp_synchronized")
    assert_not data.key?("disk_max_percent")
  end

  test "records a point of history" do
    data = parse(:debian12)
    at = Time.zone.parse("2026-10-31 12:00")

    Inventory::Collectors::Health.record(servers(:web), data, at)

    sample = servers(:web).health_samples.sole
    assert_equal [ at, 24.0, 88.0, 94.4 ], [ sample.collected_at, sample.load_percent, sample.memory_percent, sample.disk_percent ]
  end
end
