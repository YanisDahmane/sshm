require "application_system_test_case"

# AUDIT.md S1: the pages work under the Content Security Policy, without any
# violation reported by the browser (scripts, Turbo's progress bar, theme).
class ContentSecurityPolicyTest < ApplicationSystemTestCase
  include Devise::Test::IntegrationHelpers

  test "no CSP violation on the main pages, the quick search and the jobs dashboard" do
    sign_in users(:one)
    [ root_path, servers_path, server_path(servers(:web), tab: "keys"), public_keys_path, tasks_path, settings_path, settings_integrations_path, "/jobs" ].each do |path|
      visit path
      assert_selector "body"
    end
    visit servers_path
    find("body").send_keys([ :control, "k" ])
    assert_selector "#command-palette[open]"

    violations = page.driver.browser.logs.get(:browser).map(&:message).grep(/Content Security Policy|Refused to/i)
    assert_empty violations
  end

  test "the policy is sent with a nonce" do
    visit new_user_session_path
    header = page.driver.browser.execute_script("return document.querySelector('meta[name=csp-nonce]')?.content")
    assert header.present?
    assert_selector "script[nonce]", visible: :all
  end
end
