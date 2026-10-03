require "application_system_test_case"

class ServerShowTest < ApplicationSystemTestCase
  include Devise::Test::IntegrationHelpers
  include TcpHelpers
  include ActionView::RecordIdentifier

  setup do
    Server.update_all(host: "127.0.0.1", port: closed_port)
    sign_in users(:one)
  end

  test "opening a server from the dashboard" do
    visit root_path
    click_on "Web"

    assert_selector "h1", text: "Web"
    assert_selector "#server-status .server-status", text: "En ligne"
  end

  test "refreshing the status in place" do
    visit server_path(servers(:web))
    execute_script("window.noFullReload = true")

    click_on "Actualiser le statut"

    within("#server-status") { assert_selector ".server-status", text: "Injoignable" }
    assert_selector "#flash", text: "« Web » est injoignable."
    assert evaluate_script("window.noFullReload")
  end

  test "testing the SSH connection shows the result in place" do
    visit server_path(servers(:web))
    execute_script("window.noFullReload = true")

    click_on "Tester la connexion SSH"

    within("##{dom_id(servers(:web), :ssh_check)}") { assert_text "Connexion impossible" }
    assert evaluate_script("window.noFullReload")
  end

  test "authorized keys load lazily and can be reloaded" do
    visit server_path(servers(:web))

    within("#server-authorized-keys") do
      assert_selector ".authorized-keys-error", text: "Connexion impossible"
      click_on "Recharger les clés"
      assert_selector ".authorized-keys-error", text: "Connexion impossible"
    end
    assert_selector "h1", text: "Web"
  end
end
