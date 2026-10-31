require "application_system_test_case"

class ServerAuthorizationsTest < ApplicationSystemTestCase
  include Devise::Test::IntegrationHelpers
  include StubHelpers

  setup do
    sign_in users(:one)
  end

  # Simulates the authorized_keys file in memory: the reader lists it and the
  # authorization appends to it.
  test "authorizing a profile" do
    lines = [ ssh_keys(:main).public_key ]
    reader = ->(*, **) { AuthorizedKeysReader::Result.new(keys: AuthorizedKey.parse(lines.join("\n")), error_title: nil, error_details: nil) }
    authorizer = lambda do |_server, profile, **|
      lines << "#{profile.authorized_key.type} #{profile.authorized_key.key} #{profile.name}"
      ProfileAuthorization::Result.new(status: :added, error_title: nil, error_details: nil)
    end

    stub_method(AuthorizedKeysReader, :call, reader) do
      stub_method(ProfileAuthorization, :call, authorizer) do
        visit server_path(servers(:web))

        within("#server-authorized-keys") do
          assert_selector "li.authorized-key", count: 1
          select "CI", from: "Autoriser un profil"
          click_on "Autoriser"
          assert_selector ".key-profile", text: "Profil : CI"
          assert_selector "li.authorized-key", count: 2
        end
        assert_selector "#flash", text: "Le profil « CI » est maintenant autorisé sur « Web »."
      end
    end
  end

  test "authorizing a profile for a limited time shows when it expires" do
    lines = [ ssh_keys(:main).public_key ]
    reader = ->(*, **) { AuthorizedKeysReader::Result.new(keys: AuthorizedKey.parse(lines.join("\n")), error_title: nil, error_details: nil) }
    authorizer = lambda do |_server, profile, expires_at:, **|
      lines << ProfileAuthorization.line_for(profile, expires_at)
      ProfileAuthorization::Result.new(status: :added, error_title: nil, error_details: nil)
    end

    stub_method(AuthorizedKeysReader, :call, reader) do
      stub_method(ProfileAuthorization, :call, authorizer) do
        visit server_path(servers(:web))

        within("#server-authorized-keys") do
          select "CI", from: "Autoriser un profil"
          select "10 minutes", from: "Durée"
          click_on "Autoriser"

          within("li.authorized-key", text: "CI") do
            assert_selector ".key-expiry", text: "Expire dans 10 minutes"
            assert_selector "dialog.key-details .key-options", text: "expiry-time=", visible: :all
          end
        end
        assert_selector "#flash", text: "Le profil « CI » est autorisé sur « Web » pendant 10 minutes"
        assert_equal 1, TemporaryAccess.active.count
      end
    end
  end
end
