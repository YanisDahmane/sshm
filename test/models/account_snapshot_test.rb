require "test_helper"

class AccountSnapshotTest < ActiveSupport::TestCase
  setup do
    @account = AuthorizedKeysAccount.for(servers(:web), "root")
    @unnamed = SshKeyGenerator.generate.public_key.split(" ").first(2).join(" ")
  end

  def keys(*lines) = AuthorizedKey.parse(lines.join("\n"))

  test "record! creates then refreshes the snapshot of an account" do
    first = travel_to(1.hour.ago) { AccountSnapshot.record!(servers(:web), @account, keys(profiles(:alice).public_key)) }
    second = AccountSnapshot.record!(servers(:web), @account, keys(profiles(:ci).public_key, %(no-pty #{@unnamed})))

    assert_equal first, second
    assert_equal 1, AccountSnapshot.count
    assert_equal [ profiles(:ci).fingerprint, AuthorizedKey.parse(@unnamed).sole.fingerprint ], second.fingerprints
    assert_equal "no-pty", second.keys.last.options
    assert_in_delta Time.current, second.read_at, 2
  end

  test "keeps every part of the lines" do
    line = %(expiry-time="20300101000000Z" #{profiles(:alice).public_key})
    snapshot = AccountSnapshot.record!(servers(:web), @account, keys(line))

    assert_equal line, snapshot.reload.content
  end

  test "keys without profile, named or not, except the SSHM key" do
    ci_unnamed = profiles(:ci).public_key.split(" ").first(2).join(" ")
    named = SshKeyGenerator.generate(comment: "bob@desktop").public_key
    snapshot = AccountSnapshot.record!(servers(:web), @account, keys(@unnamed, named, ci_unnamed, ssh_keys(:main).public_key.split(" ").first(2).join(" "), profiles(:alice).public_key))

    orphans = snapshot.keys_without_profile(profile_fingerprints: Profile.pluck(:fingerprint).to_set, app_key: ssh_keys(:main))

    assert_equal [ nil, "bob@desktop" ], orphans.map(&:name)
  end

  test "with_fingerprint finds the snapshots holding a key" do
    with_alice = AccountSnapshot.record!(servers(:web), @account, keys(profiles(:alice).public_key))
    AccountSnapshot.record!(servers(:db), AuthorizedKeysAccount.login(servers(:db)), keys(profiles(:ci).public_key))

    assert_equal [ with_alice ], AccountSnapshot.with_fingerprint(profiles(:alice).fingerprint)
  end

  test "forget! drops a key" do
    snapshot = AccountSnapshot.record!(servers(:web), @account, keys(profiles(:alice).public_key, profiles(:ci).public_key))

    snapshot.forget!(profiles(:alice).authorized_key.key)

    assert_equal [ profiles(:ci).fingerprint ], snapshot.reload.fingerprints
  end

  test "is deleted with its server" do
    AccountSnapshot.record!(servers(:web), @account, [])
    assert_difference("AccountSnapshot.count", -1) { servers(:web).delete }
  end

  test "the first read logs every key without profile" do
    bob = SshKeyGenerator.generate(comment: "bob@desktop").public_key

    AccountSnapshot.record!(servers(:web), @account, keys(@unnamed, bob, profiles(:alice).public_key, ssh_keys(:main).public_key))

    detected = Activity.of_kind(:unknown_key_detected).order(:id)
    assert_equal [ nil, "bob@desktop" ], detected.map { |activity| activity.data["key_name"] }
    assert detected.all? { |activity| activity.server == servers(:web) && activity.unix_user == "root" }
    assert_equal 0, Activity.of_kind(:key_disappeared).count
  end

  test "later reads log only new keys without profile and vanished keys" do
    bob = SshKeyGenerator.generate(comment: "bob@desktop").public_key
    eve = SshKeyGenerator.generate(comment: "eve@laptop").public_key
    AccountSnapshot.record!(servers(:web), @account, keys(bob, profiles(:alice).public_key))
    Activity.delete_all

    AccountSnapshot.record!(servers(:web), @account, keys(bob, eve))

    assert_equal [ "eve@laptop" ], Activity.of_kind(:unknown_key_detected).map(&:key_name)
    assert_equal [ "alice@laptop" ], Activity.of_kind(:key_disappeared).map(&:key_name)
  end

  test "a key removed through SSHM is not reported as vanished" do
    snapshot = AccountSnapshot.record!(servers(:web), @account, keys(profiles(:alice).public_key))
    snapshot.forget!(profiles(:alice).authorized_key.key)

    AccountSnapshot.record!(servers(:web), @account, [])

    assert_equal 0, Activity.of_kind(:key_disappeared).count
  end

  test "the pending SSHM key is not reported as a key without profile" do
    pending = SshKey.generate_pending!

    AccountSnapshot.record!(servers(:web), @account, keys(pending.public_key))

    assert_equal 0, Activity.of_kind(:unknown_key_detected).count
  end
end
