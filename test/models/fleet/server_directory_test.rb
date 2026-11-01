require "test_helper"

class ServerDirectoryTest < ActiveSupport::TestCase
  setup do
    servers(:web).update_columns(ip_addresses: [ "10.8.0.100", "2001:db8::10" ], extra_addresses: [ "203.0.113.4" ])
    servers(:db).inventory_snapshots.create!(category: "os", status: "ok", data: { "hostname" => "fr-utils-1.example.internal" },
                                              collected_at: Time.current, checked_at: Time.current)
    @directory = ServerDirectory.new(Server.includes(:inventory_snapshots).order(:name))
  end

  test "by address: collected, added by hand, SSH host, IPv6 written any way, or a network containing one" do
    assert_equal [ servers(:web), "10.8.0.100" ], @directory.by_address("10.8.0.100").to_h.values
    assert_equal servers(:web), @directory.by_address("203.0.113.4").server
    assert_equal servers(:backup), @directory.by_address("10.0.0.5").server
    assert_equal servers(:web), @directory.by_address("2001:0db8:0::10").server
    assert_equal [ servers(:web), "203.0.113.4" ], @directory.by_address("203.0.113.0/24").to_h.values
    assert_nil @directory.by_address("10.9.9.9")
    assert_nil @directory.by_address("not an ip")
  end

  test "by host name: full, short, SSH host; the name in Elio only when asked" do
    assert_equal servers(:db), @directory.by_host("FR-UTILS-1.example.internal")
    assert_equal servers(:db), @directory.by_host("fr-utils-1")
    assert_equal servers(:db), @directory.by_host("db.example.com")
    assert_nil @directory.by_host("web")
    assert_equal servers(:web), @directory.by_host("web", names: true)
    assert_nil @directory.by_host("")
  end

  test "named in a text, as a whole word, the longest name first" do
    Server.create!(name: "Web-2", host: "10.0.0.20", username: "root")
    directory = ServerDirectory.new(Server.includes(:inventory_snapshots))
    assert_equal "Web-2", directory.named_in("[SRV] Web-2 ping").name
    assert_equal "Web", directory.named_in("Ping web").name
    assert_equal servers(:db), directory.named_in("[SRV] [INTRANET] FR-UTILS-1")
    assert_nil directory.named_in("Website")
  end
end
