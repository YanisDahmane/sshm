require "test_helper"

class ActivitiesControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  test "requires authentication" do
    get activities_path
    assert_redirected_to new_user_session_path
  end

  test "lists activities, most recent first, with author and server" do
    travel_to(1.hour.ago) { Activity.record!(:server_created, server: servers(:web)) }
    Activity.record!(:key_added, server: servers(:web), profile: profiles(:alice), unix_user: "deploy", user: users(:one))
    sign_in users(:one)

    get activities_path

    assert_select "#activities li.activity", 2
    assert_select "#activities li.activity:first-child[data-kind=key_added]" do
      assert_select "p", text: "« Alice » autorisé sur « Web » pour deploy"
      assert_select "p", text: /Clé ajoutée\s+· one@example.com/
      assert_select "a[href=?]", server_path(servers(:web))
      assert_select ".severity-info"
    end
    assert_select "nav .main-nav a[aria-current=page]", text: "Activité"
  end

  test "filters by category" do
    Activity.record!(:key_added, server: servers(:web))
    Activity.record!(:unknown_key_detected, server: servers(:web))
    sign_in users(:one)

    get activities_path(category: "security")

    assert_select "li.activity", 1
    assert_select "li.activity[data-kind=unknown_key_detected] .severity-warning"
    assert_select ".activity-filters a[aria-current=page]", text: "Sécurité"
  end

  test "ignores an unknown category" do
    Activity.record!(:key_added, server: servers(:web))
    sign_in users(:one)

    get activities_path(category: "nope")

    assert_select "li.activity", 1
    assert_select ".activity-filters a[aria-current=page]", text: "Tout"
  end

  test "filters by server" do
    Activity.record!(:key_added, server: servers(:web))
    Activity.record!(:key_added, server: servers(:db))
    sign_in users(:one)

    get activities_path(server_id: servers(:db).id)

    assert_select "li.activity", 1
    assert_select "p", text: /sur « Database »/
  end

  test "paginates" do
    (ActivitiesController::PER_PAGE + 1).times { |index| travel_to(index.minutes.ago) { Activity.record!(:server_created, server: servers(:web)) } }
    sign_in users(:one)

    get activities_path
    assert_select "li.activity", ActivitiesController::PER_PAGE
    assert_select "a[href=?]", activities_path(page: 2), text: "Plus anciennes →"

    get activities_path(page: 2)
    assert_select "li.activity", 1
    assert_select "a[href=?]", activities_path(page: 1), text: "← Plus récentes"
  end

  test "empty state" do
    sign_in users(:one)
    get activities_path
    assert_select "p", text: "Aucune activité pour le moment."
  end
end
