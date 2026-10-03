require "test_helper"

class KeyRevocationTest < ActiveSupport::TestCase
  include StubHelpers
  include TemporaryAccessHelpers

  setup do
    @account = AuthorizedKeysAccount.login(servers(:web))
    @blob = profiles(:ci).authorized_key.key
  end

  def removal(status) = AuthorizedKeyRemoval::Result.new(status: status, error_title: (status == :error ? "Connexion impossible" : nil), error_details: nil)

  test "removes the key, ends its temporary access, updates the snapshot and logs it" do
    access = create_temporary_access
    AccountSnapshot.record!(servers(:web), @account, AuthorizedKey.parse(profiles(:ci).public_key))

    result = stub_method(AuthorizedKeyRemoval, :call, removal(:removed)) do
      KeyRevocation.call(servers(:web), @blob, account: @account, key_name: "ci", profile: profiles(:ci))
    end

    assert result.removed?
    assert_not access.reload.active?
    assert_empty AccountSnapshot.sole.fingerprints
    activity = Activity.of_kind(:key_removed).sole
    assert_equal [ servers(:web), profiles(:ci), "deploy", "ci" ], [ activity.server, activity.profile, activity.unix_user, activity.key_name ]
    assert_equal 0, Activity.of_kind(:key_disappeared).count
  end

  test "an already absent key ends the access but is not logged as removed" do
    access = create_temporary_access

    stub_method(AuthorizedKeyRemoval, :call, removal(:absent)) { KeyRevocation.call(servers(:web), @blob, account: @account) }

    assert_not access.reload.active?
    assert_equal 0, Activity.count
  end

  test "changes nothing when the removal fails" do
    access = create_temporary_access

    result = stub_method(AuthorizedKeyRemoval, :call, removal(:error)) { KeyRevocation.call(servers(:web), @blob, account: @account) }

    assert_not result.success?
    assert access.reload.active?
    assert_equal 0, Activity.count
  end
end
