require "test_helper"

class TemporaryAccessTest < ActiveSupport::TestCase
  include TemporaryAccessHelpers

  test "is valid with a server, an account, a key and an expiry" do
    assert create_temporary_access.persisted?
  end

  test "requires its attributes" do
    access = TemporaryAccess.new
    assert_not access.valid?
    %i[server unix_user key_blob fingerprint expires_at].each { |attribute| assert access.errors.key?(attribute), attribute }
  end

  test "active and expired scopes" do
    valid = create_temporary_access
    expired = create_temporary_access(profile: profiles(:alice), expires_at: 1.minute.ago)
    ended = create_temporary_access(profile: profiles(:alice), unix_user: "root", expires_at: 1.minute.ago).tap(&:end!)

    assert_equal [ valid, expired ].sort, TemporaryAccess.active.sort
    assert_equal [ expired ], TemporaryAccess.expired.to_a
    assert_not ended.active?
  end

  test "only one active access per server, account and key" do
    create_temporary_access
    assert_raises(ActiveRecord::RecordNotUnique) { create_temporary_access }

    TemporaryAccess.last.end!
    assert create_temporary_access.persisted?
  end

  test "end! sets ended_at once" do
    access = create_temporary_access
    travel_to(1.minute.from_now) { access.end! }
    ended_at = access.ended_at

    access.end!
    assert_equal ended_at, access.reload.ended_at
  end

  test "account is the server's Unix account" do
    assert_equal AuthorizedKeysAccount.for(servers(:web), "root"), create_temporary_access(unix_user: "root").account
  end

  test "keeps the access when the profile is deleted" do
    access = create_temporary_access
    profiles(:ci).destroy!

    assert_nil access.reload.profile
    assert access.active?
  end

  test "durations" do
    assert_equal 10.minutes, TemporaryAccess.duration_for("10")
    assert_equal 7.days, TemporaryAccess.duration_for(10080)
    assert_raises(ArgumentError) { TemporaryAccess.duration_for("5") }
    assert_equal "1 heure", TemporaryAccess.label_for(1.hour)
  end
end
