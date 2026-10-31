require "test_helper"

class BulkAccessTest < ActiveSupport::TestCase
  include StubHelpers

  def grant_result(status) = ProfileAuthorization::Result.new(status: status, error_title: (status == :error ? "Connexion impossible" : nil), error_details: (status == :error ? "timeout" : nil))
  def removal_result(status) = AuthorizedKeyRemoval::Result.new(status: status, error_title: (status == :error ? "Connexion impossible" : nil), error_details: (status == :error ? "timeout" : nil))

  setup do
    @reads = []
    stub_method_until_teardown(AuthorizedKeysReader, :call, ->(server, account:) {
      @reads << [ server.name, account.unix_user ]
      AuthorizedKeysReader::Result.new(keys: AuthorizedKey.parse(profiles(:alice).public_key), error_title: nil, error_details: nil)
    })
  end

  test "grants every profile on every server's login user, then refreshes each snapshot once" do
    calls = []
    granter = ->(server, profile, account:, duration:) { calls << [ server.name, profile.name, account.unix_user, duration ]; grant_result(:added) }

    results = stub_method(AccessGrant, :call, granter) do
      BulkAccess.grant([ profiles(:alice), profiles(:ci) ], [ servers(:backup), servers(:web) ])
    end

    assert_equal [ [ "Backup", "Alice", "root", nil ], [ "Backup", "CI", "root", nil ], [ "Web", "Alice", "deploy", nil ], [ "Web", "CI", "deploy", nil ] ], calls
    assert_equal [ "autorisé" ] * 4, results.map(&:message)
    assert_equal [ [ "Backup", "root" ], [ "Web", "deploy" ] ], @reads
    assert AccountSnapshot.exists?(server: servers(:web), unix_user: "deploy")
  end

  test "a failed grant is an error and does not refresh the snapshot" do
    results = stub_method(AccessGrant, :call, grant_result(:error)) do
      BulkAccess.grant([ profiles(:alice) ], [ servers(:web) ])
    end

    assert results.first.error?
    assert_equal "Connexion impossible — timeout", results.first.message
    assert_empty @reads
  end

  test "revokes every profile and reports removed, absent and failed keys" do
    statuses = { profiles(:alice).authorized_key.key => :removed, profiles(:ci).authorized_key.key => :absent }
    calls = []
    remover = ->(server, blob, account:, **) { calls << [ server.name, blob, account.unix_user ]; removal_result(statuses.fetch(blob)) }

    results = stub_method(AuthorizedKeyRemoval, :call, remover) do
      BulkAccess.revoke([ profiles(:alice), profiles(:ci) ], [ servers(:web) ])
    end

    assert_equal [ [ "Web", profiles(:alice).authorized_key.key, "deploy" ], [ "Web", profiles(:ci).authorized_key.key, "deploy" ] ], calls
    assert_equal [ "retiré", "n'avait pas accès" ], results.map(&:message)
    assert_equal 1, Activity.of_kind(:key_removed).count

    failed = stub_method(AuthorizedKeyRemoval, :call, removal_result(:error)) { BulkAccess.revoke([ profiles(:alice) ], [ servers(:web) ]) }
    assert failed.first.error?
  end
end
