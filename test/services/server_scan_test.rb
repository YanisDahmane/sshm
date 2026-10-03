require "test_helper"

class ServerScanTest < ActiveSupport::TestCase
  include StubHelpers

  setup do
    @server = servers(:web)
  end

  def accounts_result(*names, error_title: nil, reason: nil)
    ServerAccountsReader::Result.new(accounts: names.map { |name| AuthorizedKeysAccount.for(@server, name) }, error_title: error_title, error_details: nil, reason: reason)
  end

  test "reads every account and records their snapshots" do
    files = { "deploy" => profiles(:alice).public_key, "root" => profiles(:ci).public_key }
    reader = lambda do |_server, account:, **|
      AuthorizedKeysReader::Result.new(keys: AuthorizedKey.parse(files.fetch(account.unix_user)), error_title: nil, error_details: nil)
    end

    result = stub_method(ServerAccountsReader, :call, accounts_result("deploy", "root")) do
      stub_method(AuthorizedKeysReader, :call, reader) { ServerScan.call(@server) }
    end

    assert result.success?
    assert_equal %w[deploy root], result.accounts.map(&:unix_user)
    assert_equal [ profiles(:alice).fingerprint ], AccountSnapshot.find_by!(server: @server, unix_user: "deploy").fingerprints
    assert_equal [ profiles(:ci).fingerprint ], AccountSnapshot.find_by!(server: @server, unix_user: "root").fingerprints
    assert @server.reload.ssh_ok
  end

  test "skips the accounts that cannot be read" do
    reader = lambda do |_server, account:, **|
      if account.root?
        AuthorizedKeysReader::Result.new(keys: [], error_title: "Accès root impossible", error_details: "sudo")
      else
        AuthorizedKeysReader::Result.new(keys: [], error_title: nil, error_details: nil)
      end
    end

    result = stub_method(ServerAccountsReader, :call, accounts_result("deploy", "root")) do
      stub_method(AuthorizedKeysReader, :call, reader) { ServerScan.call(@server) }
    end

    assert_equal %w[deploy], result.accounts.map(&:unix_user)
    assert_equal %w[deploy], AccountSnapshot.pluck(:unix_user)
  end

  test "records a refused key and reads nothing" do
    refused = accounts_result("deploy", error_title: "Clé SSH refusée par le serveur", reason: :key_refused)

    result = stub_method(ServerAccountsReader, :call, refused) do
      stub_method(AuthorizedKeysReader, :call, ->(*, **) { flunk "should not read keys" }) { ServerScan.call(@server) }
    end

    assert_not result.success?
    assert_equal false, @server.reload.ssh_ok
    assert_equal 0, AccountSnapshot.count
  end

  test "an unreachable server keeps its SSH status" do
    unreachable = accounts_result("deploy", error_title: "Connexion impossible")

    stub_method(ServerAccountsReader, :call, unreachable) { ServerScan.call(@server) }

    assert_nil @server.reload.ssh_ok
  end
end
