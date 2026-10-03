require "application_system_test_case"

class ServerAuthorizationsTest < ApplicationSystemTestCase
  include Devise::Test::IntegrationHelpers
  include StubHelpers

  setup do
    sign_in users(:one)
  end

  # Simulates the server's authorized_keys file in memory: the reader lists
  # it and the authorization appends to it.
  test "authorizing a profile updates the key list in place" do
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

          assert_selector "li.authorized-key", count: 2
          assert_selector ".key-profile", text: "Profil : CI"
          assert_no_selector "option", text: "CI"
        end
        assert_selector "#flash", text: "Le profil « CI » est maintenant autorisé sur « Web »."
      end
    end
  end
end
