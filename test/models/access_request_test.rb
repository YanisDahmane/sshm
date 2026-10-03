require "test_helper"

class AccessRequestTest < ActiveSupport::TestCase
  setup { users(:viewer).update!(profile: profiles(:ci)) }

  def build(**attributes)
    AccessRequest.new({ requester: users(:viewer), server: servers(:web), duration_minutes: 60, reason: "Incident #142" }.merge(attributes))
  end

  test "takes the requester's profile and defaults to the server's SSH user" do
    request = build
    assert request.valid?
    assert_equal profiles(:ci), request.profile
    assert_equal "deploy", request.unix_user
    assert_equal "pending", request.status
    assert_equal "1 heure", request.duration_label
  end

  test "the requester must have a profile" do
    request = build(requester: users(:operator))
    assert_not request.valid?
    assert_includes request.errors.full_messages.join, "aucun profil SSH"
  end

  test "validates the reason, the account and the duration" do
    assert_not build(reason: "  ").valid?
    assert_not build(reason: "x" * 501).valid?
    assert_not build(unix_user: "bad name;").valid?
    assert_not build(duration_minutes: 7).valid?
    request = build(unix_user: " root ")
    assert request.valid?
    assert_equal "root", request.unix_user
  end

  test "only a pending request can be decided, by an operator or admin who did not ask" do
    request = build.tap(&:save!)

    assert request.decidable_by?(users(:operator))
    assert request.decidable_by?(users(:one))
    assert_not request.decidable_by?(users(:viewer)), "viewers cannot decide"

    users(:operator).update!(profile: profiles(:alice))
    own = build(requester: users(:operator)).tap(&:save!)
    assert_not own.decidable_by?(users(:operator)), "nobody approves their own request"

    request.approve!(users(:one))
    assert_equal [ "approved", users(:one) ], [ request.status, request.decided_by ]
    assert_not request.decidable_by?(users(:operator))
  end

  test "deny keeps the note, cancel ends the request" do
    request = build.tap(&:save!)
    request.deny!(users(:one), " Pas de motif valable ")
    assert_equal [ "denied", "Pas de motif valable", "Refusée" ], [ request.status, request.decision_note, request.status_label ]

    other = build.tap(&:save!)
    other.cancel!
    assert_equal "Annulée", other.status_label
  end

  test "pending requests expire after 24 hours" do
    stale = travel_to(25.hours.ago) { build.tap(&:save!) }
    fresh = build.tap(&:save!)

    AccessRequest.expire_stale!

    assert_equal "expired", stale.reload.status
    assert_equal "pending", fresh.reload.status
    assert_equal [ fresh ], AccessRequest.pending.to_a
  end
end
