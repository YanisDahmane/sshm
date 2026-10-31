require "test_helper"

class Inventory::SnapshotTest < ActiveSupport::TestCase
  def build(**attributes)
    Inventory::Snapshot.new({ server: servers(:web), category: "os", status: "ok", checked_at: Time.current }.merge(attributes))
  end

  test "is valid with a server, a category, a status and a check time" do
    assert build.valid?
  end

  test "validations" do
    snapshot = build(category: "", status: "nope", checked_at: nil)

    assert_not snapshot.valid?
    assert_equal %i[category status checked_at].sort, snapshot.errors.attribute_names.sort
  end

  test "one snapshot per server and category" do
    build.save!

    assert_not build.valid?
    assert build(server: servers(:db)).valid?
    assert build(category: "health").valid?
  end

  test "collected? and failed?" do
    assert_not build.collected?
    assert build(collected_at: Time.current).collected?
    assert build(status: "error").failed?
  end

  test "is deleted with its server, and found through it" do
    snapshot = build(data: { "name" => "Debian" })
    snapshot.save!

    assert_equal snapshot, servers(:web).inventory("os")
    assert_nil servers(:web).inventory("health")
    assert_difference("Inventory::Snapshot.count", -1) { servers(:web).destroy! }
  end

  test "the server remembers its root access" do
    assert servers(:web).update(privilege: "sudo")
    assert_not servers(:web).update(privilege: "admin")
  end
end
