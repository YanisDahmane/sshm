require "test_helper"

class RevocationsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers
  include ActiveJob::TestHelper

  test "an admin starts a revocation and follows it" do
    sign_in users(:one)

    post profile_revocation_path(profiles(:alice)), params: { delete_profile: "1" }

    revocation = Revocation.sole
    assert revocation.delete_profile
    assert_enqueued_with(job: RevokeProfileEverywhereJob, args: [ revocation ])
    assert_redirected_to revocation_path(revocation)
    assert_equal "Révocation de « Alice » lancée sur 3 serveurs.", flash[:notice]
  end

  test "the page refreshes itself while running" do
    revocation = Revocation.start!(profiles(:alice), by: users(:one))
    revocation.steps.create!(server: servers(:web), server_name: "Web", unix_user: "deploy", status: :removed)
    sign_in users(:one)

    get revocation_path(revocation)

    assert_select "turbo-frame##{ActionView::RecordIdentifier.dom_id(revocation)}:not([src])" do
      assert_select "[data-controller=auto-refresh]"
      assert_select ".revocation-status", text: /En cours : 1\/3 serveur/
      assert_select "li.revocation-step.is-removed", text: /Web · deploy — clé retirée/
    end
  end

  test "a finished revocation stops refreshing and offers to retry the failures" do
    revocation = Revocation.start!(profiles(:alice), by: users(:one))
    revocation.steps.create!(server: servers(:db), server_name: "Database", status: :failed, error_message: "Connexion impossible — refused")
    revocation.finish!
    sign_in users(:one)

    get revocation_path(revocation)

    assert_select "[data-controller=auto-refresh]", 0
    assert_select ".revocation-status", text: /Terminée avec 1 échec/
    assert_select "li.revocation-step.is-failed", text: /comptes impossibles à lister/
    assert_select "form[action=?] button", retry_revocation_path(revocation), text: "Relancer les échecs"
  end

  test "retrying enqueues the job for the failures only" do
    revocation = Revocation.start!(profiles(:alice), by: users(:one))
    revocation.steps.create!(server: servers(:db), server_name: "Database", status: :failed, error_message: "x")
    revocation.finish!
    sign_in users(:one)

    post retry_revocation_path(revocation)

    assert_enqueued_with(job: RevokeProfileEverywhereJob, args: [ revocation, { retry_failed: true } ])
    assert revocation.reload.running?
  end

  test "nothing to retry" do
    revocation = Revocation.start!(profiles(:alice), by: users(:one)).tap(&:finish!)
    sign_in users(:one)

    post retry_revocation_path(revocation)

    assert_no_enqueued_jobs only: RevokeProfileEverywhereJob
    assert_equal "Rien à relancer.", flash[:alert]
  end

  test "the profile page offers to revoke everywhere to admins only" do
    sign_in users(:one)
    get profile_path(profiles(:alice))
    assert_select "button.revoke-everywhere"
    assert_select "dialog form[action=?] input[type=checkbox][name=delete_profile]", profile_revocation_path(profiles(:alice))

    sign_in users(:operator)
    get profile_path(profiles(:alice))
    assert_select "button.revoke-everywhere", 0
  end
end
