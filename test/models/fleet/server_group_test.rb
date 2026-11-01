require "test_helper"

class ServerGroupTest < ActiveSupport::TestCase
  test "valid with a name and a known color" do
    assert ServerGroup.new(name: "Clients", color: "emerald").valid?
  end

  test "name is required, squished, at most 50 characters and unique ignoring case" do
    assert_not ServerGroup.new(name: " ", color: "red").valid?
    assert_equal "Front web", ServerGroup.new(name: "  Front   web ").name
    assert_not ServerGroup.new(name: "x" * 51, color: "red").valid?

    duplicate = ServerGroup.new(name: "PRODUCTION", color: "red")
    assert_not duplicate.valid?
    assert duplicate.errors.of_kind?(:name, :taken)
  end

  test "the database refuses a duplicate name too" do
    assert_raises(ActiveRecord::RecordNotUnique) { ServerGroup.new(name: "production", color: "red").save!(validate: false) }
  end

  test "color must be one of the palette" do
    assert_not ServerGroup.new(name: "X", color: "bg-red-500 evil").valid?
    assert_equal "slate", ServerGroup.new.color
  end

  test "exposes the color label and classes" do
    group = server_groups(:production)
    assert_includes group.badge_classes, "bg-red-50"
    assert_equal "bg-red-500", group.dot_classes
  end

  test "has its servers sorted by name, and servers know their groups" do
    assert_equal [ servers(:db), servers(:web) ], server_groups(:production).servers.to_a
    assert_equal [ server_groups(:production) ], servers(:web).server_groups.to_a
    assert_equal [ servers(:db), servers(:web) ].sort_by(&:id), Server.in_group(server_groups(:production)).order(:id).to_a
  end

  test "a server is in a group only once" do
    membership = ServerGroupMembership.new(server: servers(:web), server_group: server_groups(:production))
    assert_not membership.valid?
  end

  test "deleting a group keeps its servers, deleting a server leaves its groups" do
    assert_no_difference "Server.count" do
      server_groups(:production).destroy!
    end
    assert_equal 0, ServerGroupMembership.count

    ServerGroupMembership.create!(server: servers(:web), server_group: server_groups(:staging))
    servers(:web).destroy!
    assert ServerGroup.exists?(server_groups(:staging).id)
    assert_empty server_groups(:staging).servers
  end
end
