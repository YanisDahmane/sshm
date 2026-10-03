require "test_helper"

class KeyInsightsTest < ActiveSupport::TestCase
  def unnamed_key = SshKeyGenerator.generate.public_key.split(" ").first(2).join(" ")

  def record(server, unix_user, *lines)
    AccountSnapshot.record!(server, AuthorizedKeysAccount.for(server, unix_user), AuthorizedKey.parse(lines.join("\n")))
  end

  test "nothing scanned yet" do
    insights = KeyInsights.new

    assert_not insights.scanned?
    assert_nil insights.last_read_at
    assert_equal 0, insights.orphan_count
    assert_equal({}, insights.orphans_by_server_id)
  end

  test "lists the keys without profile per server, once per key across accounts" do
    unnamed = unnamed_key
    bob = SshKeyGenerator.generate(comment: "bob@desktop").public_key
    record(servers(:web), "deploy", unnamed, bob, profiles(:alice).public_key)
    record(servers(:web), "root", unnamed, ssh_keys(:main).public_key)
    travel_to(1.day.ago) { record(servers(:db), "admin", profiles(:ci).public_key) }

    insights = KeyInsights.new

    assert insights.scanned?
    assert_equal [ nil, "bob@desktop" ], insights.orphans_by_server_id[servers(:web).id].map(&:name)
    assert_equal [], insights.orphans_by_server_id[servers(:db).id]
    assert_equal 2, insights.orphan_count
    assert_in_delta Time.current, insights.last_read_at, 2
  end
end
