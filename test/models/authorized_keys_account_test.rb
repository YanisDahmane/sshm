require "test_helper"

class AuthorizedKeysAccountTest < ActiveSupport::TestCase
  setup do
    @server = servers(:web) # username "deploy"
    @account = AuthorizedKeysAccount.login(@server)
  end

  test "is the SSH login user of the server" do
    assert_equal "deploy", @account.unix_user
    assert_equal "deploy", @account.name
    assert_equal @server, @account.server
  end

  test "works in the login user's home" do
    assert_equal "$HOME", @account.home
    assert_equal "~deploy/.ssh/authorized_keys", @account.path
  end

  test "runs scripts with sh, escaped" do
    assert_equal "sh -c echo\\ \\'hi\\'", @account.command("echo 'hi'")
  end

  test "shows connection errors as they are" do
    error = SshConnection::AuthenticationError.new("refused")

    assert_equal [ error.title, "refused" ], @account.error_for(error)
  end

  test "equality and hashing" do
    assert_equal @account, AuthorizedKeysAccount.login(servers(:web))
    assert_not_equal @account, AuthorizedKeysAccount.login(servers(:db))
    assert_equal 1, [ @account, AuthorizedKeysAccount.login(servers(:web)) ].uniq.size
  end
end
