require "application_system_test_case"

class ServerAuthorizationsTest < ApplicationSystemTestCase
  include Devise::Test::IntegrationHelpers
  include StubHelpers

  setup do
    sign_in users(:one)
  end

  # Simulates the authorized_keys file in memory: the reader lists it and the
  # authorization appends to it.
  test "authorizing a public_key" do
    lines = [ ssh_keys(:main).public_key ]
    reader = ->(*, **) { AuthorizedKeysReader::Result.new(keys: AuthorizedKey.parse(lines.join("\n")), error_title: nil, error_details: nil) }
    authorizer = lambda do |_server, public_key, **|
      lines << "#{public_key.authorized_key.type} #{public_key.authorized_key.key} #{public_key.name}"
      PublicKeyAuthorization::Result.new(status: :added, error_title: nil, error_details: nil)
    end

    stub_method(AuthorizedKeysReader, :call, reader) do
      stub_method(PublicKeyAuthorization, :call, authorizer) do
        visit server_path(servers(:web), tab: "keys")

        within("#server-authorized-keys") do
          assert_selector "li.authorized-key", count: 1
          select "CI", from: "Ajouter une clé du trousseau"
          click_on "Ajouter"
          assert_selector ".key-keyring", text: "CI"
          assert_selector "li.authorized-key", count: 2
        end
        assert_selector "#flash", text: "La clé « CI » a été ajoutée sur « Web »."
      end
    end
  end

  test "authorizing a public_key for a limited time shows when it expires" do
    lines = [ ssh_keys(:main).public_key ]
    reader = ->(*, **) { AuthorizedKeysReader::Result.new(keys: AuthorizedKey.parse(lines.join("\n")), error_title: nil, error_details: nil) }
    authorizer = lambda do |_server, public_key, expires_at:, **|
      lines << PublicKeyAuthorization.line_for(public_key, expires_at)
      PublicKeyAuthorization::Result.new(status: :added, error_title: nil, error_details: nil)
    end

    stub_method(AuthorizedKeysReader, :call, reader) do
      stub_method(PublicKeyAuthorization, :call, authorizer) do
        visit server_path(servers(:web), tab: "keys")

        within("#server-authorized-keys") do
          select "CI", from: "Ajouter une clé du trousseau"
          select "10 minutes", from: "Durée"
          click_on "Ajouter"

          within("li.authorized-key", text: "CI") do
            assert_selector ".key-expiry", text: "Expire dans 10 minutes"
            assert_selector "dialog.key-details .key-options", text: "expiry-time=", visible: :all
          end
        end
        assert_selector "#flash", text: "La clé « CI » est ajoutée sur « Web » pendant 10 minutes"
        assert_equal 1, TemporaryAccess.active.count
      end
    end
  end
end
