require "test_helper"

class AuthorizedKeysAccountTest < ActiveSupport::TestCase
  setup do
    @server = servers(:web) # username: deploy
    @login = AuthorizedKeysAccount.login(@server)
    @root = AuthorizedKeysAccount.for(@server, "root")
    @bob = AuthorizedKeysAccount.for(@server, "bob")
  end

  def command_error(stderr)
    SshConnection::CommandError.new("sh -c ...", SshConnection::Result.new(stdout: "", stderr: stderr, exit_status: 1))
  end

  test "accepts usual Unix user names" do
    %w[root deploy ubuntu _apt www-data john.doe user_1].each do |name|
      assert_equal name, AuthorizedKeysAccount.for(@server, name).unix_user
    end
  end

  test "rejects names that are not safe Unix user names" do
    [ nil, "", "-bob", "1abc", "bob smith", "bob;rm", "../root", "~bob", "$(id)", "a" * 33 ].each do |name|
      assert_raises(ArgumentError, "#{name.inspect} should be rejected") { AuthorizedKeysAccount.for(@server, name) }
    end
  end

  test "the login account runs commands directly in $HOME" do
    assert_equal "deploy", @login.unix_user
    assert @login.login?
    assert_not @login.sudo?
    assert_equal "$HOME", @login.home
    assert_nil @login.owner
    assert_equal "~deploy/.ssh/authorized_keys", @login.path
    assert_equal "sh -c echo\\ hi", @login.command("echo hi")
  end

  test "root goes through sudo when the login user is not root" do
    assert @root.root?
    assert @root.sudo?
    assert_equal "~root", @root.home
    assert_nil @root.owner
    assert_equal "sudo -n sh -c echo\\ hi", @root.command("echo hi")
  end

  test "another user goes through sudo and gets its files back" do
    assert @bob.sudo?
    assert_equal "~bob", @bob.home
    assert_equal "bob", @bob.owner
    assert_equal "~bob/.ssh/authorized_keys", @bob.path
  end

  test "no sudo when logging in as root, but other users still get their files back" do
    @server.username = "root"

    root = AuthorizedKeysAccount.login(@server)
    bob = AuthorizedKeysAccount.for(@server, "bob")

    assert root.login?
    assert_equal "$HOME", root.home
    assert_not bob.sudo?
    assert_equal "sh -c echo\\ hi", bob.command("echo hi")
    assert_equal "bob", bob.owner
  end

  test "explains an unknown user" do
    title, details = @bob.error_for(command_error("unknown user\n"))

    assert_equal "Utilisateur inconnu", title
    assert_equal "L'utilisateur bob n'existe pas sur Web.", details
  end

  test "explains sudo failures" do
    title, details = @root.error_for(command_error("sudo: a password is required\n"))

    assert_equal "Accès root impossible", title
    assert_equal "sudo: a password is required — l'utilisateur deploy doit pouvoir lancer sudo sans mot de passe.", details
  end

  test "keeps other errors as they are" do
    assert_equal "La commande a échoué", @root.error_for(command_error("Permission denied\n")).first
    assert_equal [ "Connexion impossible", "refused" ], @root.error_for(SshConnection::ConnectionError.new("refused"))
    assert_equal "La commande a échoué", @login.error_for(command_error("sudo: nope")).first
  end

  test "equality and hashing" do
    assert_equal @root, AuthorizedKeysAccount.for(@server, "root")
    assert_not_equal @root, @bob
    assert_equal [ @login, @root ], [ @login, @root ] | [ AuthorizedKeysAccount.for(@server, "root") ]
  end
end
