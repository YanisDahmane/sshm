require "application_system_test_case"

class NotificationChannelsTest < ApplicationSystemTestCase
  include Devise::Test::IntegrationHelpers
  include StubHelpers
  include SlackHelpers

  setup do
    sign_in users(:one)
    # The app server runs in another thread: stub for the whole test so no request reaches Slack.
    @tests = []
    stub_method_until_teardown(SlackNotifier, :post, ->(url, payload) { @tests << [ url, payload ] })
  end

  test "adding a Slack channel, sending a test and deleting it" do
    visit settings_path
    within("nav.settings-nav") { click_on "Notifications" }
    click_on "Ajouter un canal Slack"

    fill_in "Nom", with: "#ops"
    fill_in "URL du webhook Slack", with: WEBHOOK
    within(".activity-kind-group", text: "Clés SSH") { click_on "Tout / rien" }
    check "Mentionner"
    click_on "Ajouter le canal"

    assert_text "Le canal « #ops » a été ajouté."
    within("section.notification-channel") do
      assert_selector ".channel-mention", text: "@channel"
      assert_selector ".channel-kind", text: "Clé ajoutée"
      assert_selector ".channel-kind", text: "Clé sans profil détectée"
    end

    click_on "Envoyer un test"
    assert_text "Message de test envoyé à « #ops »."
    assert_equal WEBHOOK, @tests.sole.first
    assert @tests.sole.last[:text].start_with?("<!channel> :white_check_mark: Test SSHM")

    accept_app_confirm { find("section.notification-channel button[title=Supprimer]").click }
    assert_text "Le canal « #ops » a été supprimé."
    assert_text "Aucun canal de notification pour le moment."
  end
end
