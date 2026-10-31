require "test_helper"

class PublicKeyAccessOverviewTest < ActiveSupport::TestCase
  include TemporaryAccessHelpers

  def record(server, *lines)
    AccountSnapshot.record!(server, AuthorizedKeysAccount.login(server), AuthorizedKey.parse(lines.join("\n")))
  end

  test "lists the servers holding the public_key's key, sorted, with temporary accesses" do
    record(servers(:web), %(expiry-time="20300101000000Z" #{public_keys(:ci).content}))
    record(servers(:db), public_keys(:ci).content.split(" ").first(2).join(" ") + " renamed")
    record(servers(:backup), public_keys(:alice).content)
    temporary = create_temporary_access(unix_user: "deploy")

    accesses = PublicKeyAccessOverview.new(public_keys(:ci)).accesses

    assert_equal [ [ "Database", "admin" ], [ "Web", "deploy" ] ], accesses.map { |access| [ access.server.name, access.unix_user ] }
    assert_equal [ nil, temporary ], accesses.map(&:temporary_access)
  end

  test "empty when the key was never seen" do
    assert_empty PublicKeyAccessOverview.new(public_keys(:alice)).accesses
  end
end
