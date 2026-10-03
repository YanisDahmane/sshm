require "test_helper"

class DriftDetectorTest < ActiveSupport::TestCase
  include StubHelpers

  def snapshot(server, unix_user, *lines)
    AccountSnapshot.create!(server: server, unix_user: unix_user, read_at: 1.minute.ago, content: lines.join("\n"))
  end

  def line(profile_or_key, comment: nil, options: nil)
    type, blob, original = profile_or_key.public_key.split
    [ options, type, blob, comment || original ].compact.join(" ")
  end

  test "no rules, no entries (unmanaged accounts are never reported)" do
    snapshot(servers(:web), "deploy", line(profiles(:alice)))
    report = DriftDetector.call

    assert_empty report.entries
    assert report.clean?
  end

  test "an account never read is listed as unscanned, not as drift" do
    AccessRule.create!(profile: profiles(:alice), server: servers(:web))
    entry = DriftDetector.call.entries.sole

    assert_not entry.scanned?
    assert_not entry.drift?
    assert_equal [ entry ], DriftDetector.call.unscanned
  end

  test "reports missing profiles and extra keys of the covered accounts" do
    AccessRule.create!(team: teams(:developers), server: servers(:web))
    stranger = SshKeyGenerator.generate(comment: "bob@desktop")
    snapshot(servers(:web), "deploy", line(profiles(:ci)), stranger.public_key, stranger.public_key)

    report = DriftDetector.call
    entry = report.entry_for(servers(:web), "deploy")

    assert entry.drift?
    assert_equal [ profiles(:alice) ], entry.missing
    assert_equal [ "bob@desktop" ], entry.extra.map(&:name), "duplicated lines count once"
    assert_equal [ 1, 1 ], [ report.missing_count, report.extra_count ]
    assert_equal [ "+#{servers(:web).id}:deploy:#{profiles(:alice).fingerprint}", "-#{servers(:web).id}:deploy:#{stranger.fingerprint}" ], report.signature
  end

  test "keys are compared by fingerprint: a renamed comment or added options are not drift" do
    AccessRule.create!(profile: profiles(:alice), server: servers(:web))
    snapshot(servers(:web), "deploy", line(profiles(:alice), comment: "renamed", options: 'from="10.0.0.1"'))

    entry = DriftDetector.call.entries.sole
    assert entry.scanned?
    assert_not entry.drift?
  end

  test "SSHM's keys and active temporary accesses are never extra; another profile's key is" do
    AccessRule.create!(profile: profiles(:alice), server: servers(:web))
    snapshot(servers(:web), "deploy", line(profiles(:alice)), ssh_keys(:main).public_key, line(profiles(:ci)))
    TemporaryAccess.create!(server: servers(:web), profile: profiles(:ci), unix_user: "deploy", key_blob: profiles(:ci).authorized_key.key,
                            fingerprint: profiles(:ci).fingerprint, expires_at: 10.minutes.from_now)

    assert DriftDetector.call.clean?

    TemporaryAccess.update_all(ended_at: Time.current)
    entry = DriftDetector.call.entries.sole
    assert_equal [ profiles(:ci).fingerprint ], entry.extra.map(&:fingerprint)
    assert_equal profiles(:ci), entry.profile_for(entry.extra.first)
  end

  test "named accounts and groups are expanded, entries sorted by server then account" do
    AccessRule.create!(profile: profiles(:alice), server_group: server_groups(:production), unix_user: "root")
    AccessRule.create!(profile: profiles(:alice), server: servers(:web))

    assert_equal [ [ "Database", "root" ], [ "Web", "deploy" ], [ "Web", "root" ] ],
                 DriftDetector.call.entries.map { |entry| [ entry.server.name, entry.unix_user ] }
  end

  test "DriftCorrection adds only the missing keys of scanned accounts" do
    AccessRule.create!(team: teams(:developers), server_group: server_groups(:production))
    snapshot(servers(:web), "deploy", line(profiles(:ci)))
    report = DriftDetector.call
    calls = []

    results = stub_method(BulkAccess, :grant, ->(profiles, servers, account:) { calls << [ profiles, servers, account ]; [ :done ] }) do
      DriftCorrection.add_missing(report.entries)
    end

    assert_equal [ [ [ profiles(:alice) ], [ servers(:web) ], "deploy" ] ], calls
    assert_equal [ :done ], results
  end
end
