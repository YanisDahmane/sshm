require "test_helper"

class ProfileAccessOverviewTest < ActiveSupport::TestCase
  include TemporaryAccessHelpers

  def record(server, unix_user, *lines)
    AccountSnapshot.record!(server, AuthorizedKeysAccount.for(server, unix_user), AuthorizedKey.parse(lines.join("\n")))
  end

  test "lists the server accounts holding the profile's key, sorted, with temporary accesses" do
    record(servers(:web), "root", profiles(:ci).public_key)
    record(servers(:web), "deploy", %(expiry-time="20300101000000Z" #{profiles(:ci).public_key}))
    record(servers(:db), "admin", profiles(:ci).public_key.split(" ").first(2).join(" ") + " renamed")
    record(servers(:backup), "root", profiles(:alice).public_key)
    temporary = create_temporary_access(unix_user: "deploy")

    accesses = ProfileAccessOverview.new(profiles(:ci)).accesses

    assert_equal [ [ "Database", "admin" ], [ "Web", "deploy" ], [ "Web", "root" ] ], accesses.map { |access| [ access.server.name, access.unix_user ] }
    assert_equal [ nil, temporary, nil ], accesses.map(&:temporary_access)
  end

  test "empty when the key was never seen" do
    assert_empty ProfileAccessOverview.new(profiles(:alice)).accesses
  end
end
