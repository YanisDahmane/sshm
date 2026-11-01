require "test_helper"

class ServerAddressesTest < ActiveSupport::TestCase
  def record_os(server, hostname)
    server.inventory_snapshots.find_or_initialize_by(category: "os").update!(status: "ok", data: { "hostname" => hostname }, collected_at: Time.current, checked_at: Time.current)
    server.inventory_snapshots.reset
  end

  test "addresses: SSH host when it is an IP, collected, then added by hand, without duplicates" do
    server = servers(:web)
    server.update!(extra_addresses_text: "203.0.113.4, 10.8.0.10;192.168.1.10")
    server.update_columns(ip_addresses: [ "2001:db8::1", "10.8.0.10" ])

    assert_equal [ "192.168.1.10", "2001:db8::1", "10.8.0.10", "203.0.113.4" ], server.addresses
    assert_equal "203.0.113.4, 10.8.0.10, 192.168.1.10", server.extra_addresses_text
    assert_equal [ "2001:db8::1", "10.8.0.10" ], servers(:db).tap { |db| db.update_columns(ip_addresses: [ "2001:db8::1", "10.8.0.10" ]) }.addresses, "a host name is not an address"
  end

  test "rejects added addresses that are not IPs" do
    server = servers(:web)
    server.extra_addresses_text = "203.0.113.4, example.com, 300.1.1.1"
    assert_not server.valid?
    assert_equal [ "Les adresses supplémentaires contiennent des valeurs qui ne sont pas des adresses IP : example.com, 300.1.1.1" ], server.errors.full_messages
  end

  test "with_address finds a server by collected, added or SSH address" do
    servers(:web).update_columns(ip_addresses: [ "10.8.0.10" ])
    servers(:db).update_columns(extra_addresses: [ "203.0.113.9" ])

    assert_equal [ servers(:web) ], Server.with_address("10.8.0.10").to_a
    assert_equal [ servers(:db) ], Server.with_address("203.0.113.9").to_a
    assert_equal [ servers(:backup) ], Server.with_address("10.0.0.5").to_a
    assert_empty Server.with_address("10.9.9.9")
  end

  test "host name, shown when it differs from the name" do
    server = servers(:web)
    assert_nil server.hostname

    record_os(server, "web")
    assert_nil server.distinct_hostname

    record_os(server.reload, "fr-prod-web-1.example.internal")
    assert_equal "fr-prod-web-1.example.internal", server.distinct_hostname
  end

  test "search by name, host, host name or part of an address" do
    server = servers(:web)
    record_os(server, "fr-prod-web-1")
    server.update_columns(ip_addresses: [ "10.8.0.10" ])

    assert server.matches_search?("WEB")
    assert server.matches_search?("prod-web")
    assert server.matches_search?("10.8.0")
    assert server.matches_search?("web 192.168")
    assert_not server.matches_search?("database")
  end
end
