require "test_helper"

class AccessRequestsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers
  include StubHelpers
  include ActionView::RecordIdentifier

  setup do
    users(:viewer).update!(profile: profiles(:ci))
    stub_method_until_teardown(AuthorizedKeysReader, :call, AuthorizedKeysReader::Result.new(keys: [], error_title: nil, error_details: nil))
  end

  def pending_request(requester: users(:viewer), **attributes)
    AccessRequest.create!({ requester: requester, server: servers(:web), duration_minutes: 60, reason: "Incident #142" }.merge(attributes))
  end

  def grant_result(status) = ProfileAuthorization::Result.new(status: status, error_title: (status == :error ? "Connexion impossible" : nil), error_details: (status == :error ? "timeout" : nil))

  test "requires authentication" do
    get access_requests_path
    assert_redirected_to new_user_session_path
  end

  test "anyone with a profile can request an access" do
    sign_in users(:viewer)
    get new_access_request_path(server_id: servers(:db).id)

    assert_response :success
    assert_select "a[href=?]", profile_path(profiles(:ci)), text: "CI"
    assert_select "select[name='access_request[server_id]'] option[selected][value=?]", servers(:db).id.to_s
    assert_select "select[name='access_request[duration_minutes]'] option", TemporaryAccess::DURATIONS.size

    assert_difference -> { AccessRequest.count } => 1, -> { Activity.of_kind(:access_requested).count } => 1 do
      post access_requests_path, params: { access_request: { server_id: servers(:db).id, unix_user: "", duration_minutes: "240", reason: "Migration" } }
    end

    assert_redirected_to access_requests_path
    request = AccessRequest.last
    assert_equal [ users(:viewer), profiles(:ci), "admin", 240 ], [ request.requester, request.profile, request.unix_user, request.duration_minutes ]
    assert_equal "viewer@example.com demande 4 heures d'accès à « Database » pour admin : « Migration »", Activity.last.summary
  end

  test "without a profile, the form explains how to get one and creation fails" do
    sign_in users(:operator)

    get new_access_request_path
    assert_select ".no-profile", text: /relié à aucun profil/
    assert_select "form[action=?]", access_requests_path, 0

    post access_requests_path, params: { access_request: { server_id: servers(:web).id, duration_minutes: "60", reason: "x" } }
    assert_response :unprocessable_entity
  end

  test "an invalid request re-renders the form" do
    sign_in users(:viewer)

    assert_no_difference("AccessRequest.count") do
      post access_requests_path, params: { access_request: { server_id: servers(:web).id, duration_minutes: "60", reason: "" } }
    end
    assert_response :unprocessable_entity
    assert_select "#error_explanation li", text: /Motif/
  end

  test "viewers see only their own requests, operators also the pending ones and the history" do
    mine = pending_request
    users(:operator).update!(profile: profiles(:alice))
    other = pending_request(requester: users(:operator))
    sign_in users(:viewer)

    get access_requests_path
    assert_select "nav.access-tabs a[aria-current=page]", text: /Demandes/
    assert_select "#my-requests ##{dom_id(mine)}" do
      assert_select ".request-status", "En attente"
      assert_select "form[action=?]", cancel_access_request_path(mine)
    end
    assert_select "##{dom_id(other)}", 0
    assert_select "#pending-requests", 0

    sign_in users(:one)
    get access_requests_path
    assert_select "nav.access-tabs .pending-count", "2"
    assert_select "#pending-requests ##{dom_id(mine)}" do
      assert_select "span", text: "viewer@example.com"
      assert_select ".request-reason", "« Incident #142 »"
      assert_select "form[action=?] button", approve_access_request_path(mine), text: "Accepter"
      assert_select "form[action=?] input[name=decision_note]", deny_access_request_path(mine)
    end
  end

  test "an operator does not get the buttons on their own request" do
    users(:operator).update!(profile: profiles(:alice))
    own = pending_request(requester: users(:operator))
    sign_in users(:operator)

    get access_requests_path
    assert_select "#pending-requests ##{dom_id(own)} .own-request"
    assert_select "#pending-requests ##{dom_id(own)} form", 0

    post approve_access_request_path(own)
    assert_redirected_to access_requests_path
    assert_equal "Vous ne pouvez pas décider de cette demande.", flash[:alert]
    assert own.reload.pending?
  end

  test "approving grants the temporary access and logs it" do
    request = pending_request(unix_user: "root")
    sign_in users(:operator)
    calls = []

    stub_method(AccessGrant, :call, ->(server, profile, account:, duration:) { calls << [ server.name, profile.name, account.unix_user, duration ]; grant_result(:added) }) do
      post approve_access_request_path(request)
    end

    assert_redirected_to access_requests_path
    assert_equal [ [ "Web", "CI", "root", 1.hour ] ], calls
    assert_equal [ "approved", users(:operator) ], [ request.reload.status, request.decided_by ]
    assert_equal "Accès accordé à viewer@example.com sur « Web » pendant 1 heure.", flash[:notice]
    assert_equal "Demande de viewer@example.com acceptée : accès à « Web » pour root pendant 1 heure", Activity.last.summary
  end

  test "a failed grant leaves the request pending" do
    request = pending_request
    sign_in users(:one)

    stub_method(AccessGrant, :call, grant_result(:error)) { post approve_access_request_path(request) }

    assert_match "Impossible d'accorder l'accès : Connexion impossible — timeout", flash[:alert]
    assert request.reload.pending?
    assert_equal 0, Activity.of_kind(:access_request_approved).count
  end

  test "denying keeps the note and logs it" do
    request = pending_request
    sign_in users(:one)

    post deny_access_request_path(request), params: { decision_note: "Passez par l'astreinte" }

    assert_redirected_to access_requests_path
    assert_equal [ "denied", "Passez par l'astreinte" ], [ request.reload.status, request.decision_note ]
    assert_equal "Demande de viewer@example.com pour « Web » pour deploy refusée : « Passez par l'astreinte »", Activity.last.summary
  end

  test "an expired request cannot be approved any more" do
    request = travel_to(25.hours.ago) { pending_request }
    sign_in users(:one)

    stub_method(AccessGrant, :call, ->(*) { flunk "must not grant" }) { post approve_access_request_path(request) }

    assert_equal "expired", request.reload.status
    assert_equal "Vous ne pouvez pas décider de cette demande.", flash[:alert]
  end

  test "the requester can cancel a pending request, nobody else" do
    request = pending_request
    sign_in users(:one)
    post cancel_access_request_path(request)
    assert_equal "Vous ne pouvez pas annuler cette demande.", flash[:alert]

    sign_in users(:viewer)
    post cancel_access_request_path(request)
    assert_equal "cancelled", request.reload.status
  end

  test "viewers cannot approve or deny" do
    request = pending_request
    sign_in users(:viewer)

    post deny_access_request_path(request)
    assert_response :forbidden
    assert request.reload.pending?
  end

  test "the server page offers to request an access to users with a profile" do
    sign_in users(:viewer)
    stub_method(ServerPing, :reachable?, true) { get server_path(servers(:web)) }
    assert_select "a.request-access[href=?]", new_access_request_path(server_id: servers(:web).id)

    sign_in users(:operator)
    stub_method(ServerPing, :reachable?, true) { get server_path(servers(:web)) }
    assert_select "a.request-access", 0
  end
end
