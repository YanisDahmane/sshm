require "test_helper"

class KeyInsightsTest < ActiveSupport::TestCase
  def unnamed_key = Ssh::KeyGenerator.generate.public_key.split(" ").first(2).join(" ")

  def record(server, *lines)
    AccountSnapshot.record!(server, AuthorizedKeysAccount.login(server), AuthorizedKey.parse(lines.join("\n")))
  end

  test "nothing scanned yet" do
    insights = KeyInsights.new

    assert_not insights.scanned?
    assert_nil insights.last_read_at
    assert_equal 0, insights.orphan_count
    assert_equal({}, insights.orphans_by_server_id)
  end

  test "lists the keys without public_key per server" do
    unnamed = unnamed_key
    bob = Ssh::KeyGenerator.generate(comment: "bob@desktop").public_key
    record(servers(:web), unnamed, bob, public_keys(:alice).content, ssh_keys(:main).public_key)
    travel_to(1.day.ago) { record(servers(:db), public_keys(:ci).content) }

    insights = KeyInsights.new

    assert insights.scanned?
    assert_equal [ nil, "bob@desktop" ], insights.orphans_by_server_id[servers(:web).id].map(&:name)
    assert_equal [], insights.orphans_by_server_id[servers(:db).id]
    assert_equal 2, insights.orphan_count
    assert_in_delta Time.current, insights.last_read_at, 2
  end
end
