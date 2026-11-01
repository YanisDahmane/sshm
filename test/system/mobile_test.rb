require "application_system_test_case"

# On a phone, no page scrolls sideways (wide tables scroll inside their card)
# and the sidebar is a drawer.
class MobileTest < ApplicationSystemTestCase
  include Devise::Test::IntegrationHelpers
  include PortHelpers

  setup do
    sign_in users(:one)
    record_ports(servers(:web))
    page.driver.browser.manage.window.resize_to(400, 860) # Chrome headless keeps at least 500 px
  end

  teardown { page.driver.browser.manage.window.resize_to(1400, 1400) }

  test "no page is wider than the screen" do
    [ root_path, servers_path, servers_path(view: "grid"), server_path(servers(:web)), server_path(servers(:web), tab: "keys"), server_path(servers(:web), tab: "ports"),
      ports_path, packages_path, public_keys_path, activities_path, tasks_path, settings_automations_path, settings_users_path,
      scheduled_tasks_path, vulnerabilities_path, settings_vulnerabilities_path ].each do |path|
      visit path
      assert_selector "h1"
      overflow = evaluate_script("document.documentElement.scrollWidth - document.documentElement.clientWidth")
      assert_operator overflow, :<=, 0, "#{path} scrolls sideways by #{overflow} px"
    end
  end

  test "the sidebar opens as a drawer" do
    visit root_path
    assert_no_selector "nav.main-nav a", text: "Parc" # off screen
    find("button[aria-label='Ouvrir le menu']").click
    within("nav.main-nav") { click_on "Tâches" }
    assert_selector "h1", text: "Tâches"
  end
end
