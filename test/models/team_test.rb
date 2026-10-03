require "test_helper"

class TeamTest < ActiveSupport::TestCase
  test "valid with a name" do
    assert Team.new(name: "Ops").valid?
  end

  test "name is required, squished, at most 50 characters and unique ignoring case" do
    assert_not Team.new(name: "  ").valid?
    assert_equal "Front end", Team.new(name: " Front   end ").name
    assert_not Team.new(name: "x" * 51).valid?

    duplicate = Team.new(name: "développeurs")
    assert_not duplicate.valid?
    assert duplicate.errors.of_kind?(:name, :taken)
    assert_raises(ActiveRecord::RecordNotUnique) { duplicate.save!(validate: false) }
  end

  test "description is optional, blank becomes nil, at most 500 characters" do
    assert_nil Team.new(name: "X", description: "  ").description
    assert_not Team.new(name: "X", description: "x" * 501).valid?
  end

  test "has its profiles sorted by name, and profiles know their teams" do
    assert_equal [ profiles(:alice), profiles(:ci) ], teams(:developers).profiles.to_a
    assert_equal [ teams(:developers) ], profiles(:alice).teams.to_a
    assert_not TeamMembership.new(team: teams(:developers), profile: profiles(:alice)).valid?
  end

  test "deleting a team keeps its profiles, deleting a profile leaves its teams" do
    assert_no_difference("Profile.count") { teams(:developers).destroy! }
    assert_equal 0, TeamMembership.count

    TeamMembership.create!(team: teams(:oncall), profile: profiles(:ci))
    profiles(:ci).destroy!
    assert_empty teams(:oncall).reload.profiles
  end
end
