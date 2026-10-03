require "test_helper"

class SettingsPagesTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers
  include ActiveJob::TestHelper

  test "every settings page requires authentication" do
    [ settings_path, settings_notifications_path, settings_automations_path ].each do |path|
      get path
      assert_redirected_to new_user_session_path
    end
  end

  test "settings pages share tabs, the current one highlighted" do
    sign_in users(:one)

    { settings_path => "Général", settings_notifications_path => "Notifications", settings_automations_path => "Automatisations" }.each do |path, label|
      get path
      assert_select "nav.settings-nav a", 3
      assert_select "nav.settings-nav a[aria-current=page]", label
      assert_select "nav a[title=Paramètres][aria-current=page]"
    end
  end

  test "the general settings keep the SSH key" do
    sign_in users(:one)
    get settings_path
    assert_select "#ssh-key-fingerprint", ssh_keys(:main).fingerprint
  end

  test "the notifications page lists every activity kind by category" do
    sign_in users(:one)

    get settings_notifications_path

    assert_select "section.notification-category", Activity::CATEGORIES.size
    Activity::KINDS.each_value do |kind|
      assert_select "#notification-#{kind.key}", text: /#{Regexp.escape(kind.label)}/ do
        assert_select "input[type=checkbox][disabled]"
      end
    end
  end

  test "the automations page lists the automations with their state" do
    Automation.all_kinds.first.update!(enabled: true, last_run_at: 1.hour.ago, last_result: "3/3 serveur(s) scanné(s)")
    sign_in users(:one)

    get settings_automations_path

    assert_select "section.automation", 2
    scan = Automation.find_by!(kind: "keys_scan")
    assert_select "##{ActionView::RecordIdentifier.dom_id(scan)}" do
      assert_select ".automation-state", "Activée"
      assert_select ".automation-result", "3/3 serveur(s) scanné(s)"
      assert_select "form[action=?] input[type=checkbox][name='automation[enabled]'][checked]", settings_automation_path(scan)
      assert_select "select[name='automation[interval_minutes]'] option[selected][value='360']", "Toutes les 6 heures"
      assert_select "form[action=?] button", run_settings_automation_path(scan), text: "Lancer maintenant"
    end
    assert_select "##{ActionView::RecordIdentifier.dom_id(Automation.find_by!(kind: "servers_ping"))} .automation-state", "Désactivée"
  end

  test "enabling an automation and choosing its frequency" do
    scan = Automation.all_kinds.first
    sign_in users(:one)

    patch settings_automation_path(scan), params: { automation: { enabled: "1", interval_minutes: "60" } }

    assert_redirected_to settings_automations_path
    assert_equal "« Scan des clés » activée (toutes les heures).", flash[:notice]
    assert scan.reload.enabled?
    assert_equal 60, scan.interval_minutes
  end

  test "disabling an automation" do
    scan = Automation.all_kinds.first
    scan.update!(enabled: true)
    sign_in users(:one)

    patch settings_automation_path(scan), params: { automation: { enabled: "0", interval_minutes: "360" } }

    assert_not scan.reload.enabled?
    assert_equal "« Scan des clés » désactivée.", flash[:notice]
  end

  test "rejects a frequency that is not offered" do
    scan = Automation.all_kinds.first
    sign_in users(:one)

    patch settings_automation_path(scan), params: { automation: { enabled: "1", interval_minutes: "7" } }

    assert_redirected_to settings_automations_path
    assert flash[:alert].present?
    assert_equal 360, scan.reload.interval_minutes
  end

  test "running an automation now enqueues it" do
    scan = Automation.all_kinds.first
    sign_in users(:one)

    post run_settings_automation_path(scan)

    assert_enqueued_with(job: RunAutomationJob, args: [ scan ])
    assert_redirected_to settings_automations_path
  end
end
