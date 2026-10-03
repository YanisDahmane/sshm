require "test_helper"

class RevocationTest < ActiveSupport::TestCase
  def start(**options) = Revocation.start!(profiles(:alice), by: users(:one), **options)

  test "start! copies the profile's name and key and counts the servers" do
    revocation = start

    assert_equal [ "Alice", profiles(:alice).fingerprint, profiles(:alice).authorized_key.key, users(:one), 3 ],
                 [ revocation.profile_name, revocation.fingerprint, revocation.key_blob, revocation.started_by, revocation.servers_count ]
    assert revocation.running?
    assert_equal :running, revocation.status
  end

  test "counts the servers done and the results" do
    revocation = start
    revocation.steps.create!(server: servers(:web), server_name: "Web", unix_user: "deploy", status: :removed)
    revocation.steps.create!(server: servers(:web), server_name: "Web", unix_user: "root", status: :absent)
    revocation.steps.create!(server: servers(:db), server_name: "Database", status: :failed, error_message: "x")

    assert_equal 2, revocation.servers_done
    assert_equal 1, revocation.removed_count
    assert_equal 1, revocation.failed_count
    assert revocation.steps.find_by(server_name: "Database").server_level?
  end

  test "finish! logs the result" do
    revocation = start
    revocation.steps.create!(server: servers(:web), server_name: "Web", unix_user: "deploy", status: :removed)

    revocation.finish!

    assert_equal :succeeded, revocation.status
    assert_equal "Clé de « Alice » retirée partout : 1 compte(s)", Activity.of_kind(:profile_revoked_everywhere).sole.summary
    assert Profile.exists?(profiles(:alice).id)
  end

  test "finish! deletes the profile when asked and nothing failed" do
    revocation = start(delete_profile: true)

    revocation.finish!

    assert_not Profile.exists?(profiles(:alice).id)
    assert_nil revocation.reload.profile
    assert_equal "Alice", revocation.profile_name
    assert_equal 1, Activity.of_kind(:profile_deleted).count
  end

  test "finish! keeps the profile when something failed" do
    revocation = start(delete_profile: true)
    revocation.steps.create!(server: servers(:db), server_name: "Database", status: :failed, error_message: "x")

    revocation.finish!

    assert_equal :partial, revocation.status
    assert Profile.exists?(profiles(:alice).id)
    assert_match "1 échec(s)", Activity.of_kind(:profile_revoked_everywhere).sole.summary
  end
end
