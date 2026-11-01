require "test_helper"

# Constraints added by the audit (AUDIT.md, pass 1).
class AuditConstraintsTest < ActiveSupport::TestCase
  test "server and keyring names are unique whatever the case, in the database too" do
    assert_raises(ActiveRecord::RecordNotUnique) do
      Server.transaction(requires_new: true) { Server.insert_all!([ { name: "WEB", host: "10.0.0.9", port: 22, username: "root" } ]) }
    end
    assert_raises(ActiveRecord::RecordNotUnique) do
      PublicKey.transaction(requires_new: true) { PublicKey.insert_all!([ { name: "ALICE", kind: "person", content: "x", fingerprint: "SHA256:other" } ]) }
    end
  end

  test "the SSH user is a POSIX account name" do
    server = servers(:web)
    %w[root deploy ubuntu svc_backup web-1 j.doe].each do |name|
      server.username = name
      assert server.valid?, name
    end
    [ "root; rm -rf /", "-oProxyCommand", "a b", "x" * 33, "élio" ].each do |name|
      server.username = name
      assert_not server.valid?, name
    end
  end

  test "passwords have 12 characters at least" do
    user = User.new(email: "new@example.com", password: "elevenchars", password_confirmation: "elevenchars")
    assert_not user.valid?
    user.password = user.password_confirmation = "twelve-chars"
    assert user.valid?
  end
end
