require "test_helper"

class InvitationTest < ActiveSupport::TestCase
  def invite(**attributes) = Invitation.create!({ email: "dave@example.com", invited_by: users(:one) }.merge(attributes))

  test "gets a random token and expires in 7 days" do
    freeze_time do
      invitation = invite(email: " Dave@Example.com ")

      assert_equal "dave@example.com", invitation.email
      assert_operator invitation.token.length, :>=, 40
      assert_equal 7.days.from_now, invitation.expires_at
      assert invitation.viewer?
      assert invitation.pending?
      assert_equal :pending, invitation.status
    end
  end

  test "the token is encrypted at rest and can be looked up" do
    invitation = invite

    raw = Invitation.connection.select_value("SELECT token FROM invitations WHERE id = #{invitation.id}")
    assert_not_includes raw, invitation.token
    assert_equal invitation, Invitation.find_pending_by_token(invitation.token)
  end

  test "validations" do
    invitation = Invitation.new(email: "nope", invited_by: users(:one), role: "root")
    assert_not invitation.valid?
    assert invitation.errors.key?(:email)
    assert invitation.errors.key?(:role)
  end

  test "cannot invite an existing user or someone already invited" do
    taken = Invitation.new(email: "OPERATOR@example.com", invited_by: users(:one))
    assert_not taken.valid?
    assert taken.errors.added?(:email, :taken_by_user)

    invite
    again = Invitation.new(email: "dave@example.com", invited_by: users(:one))
    assert_not again.valid?
    assert again.errors.added?(:email, :already_invited)
  end

  test "can invite again once the previous invitation is revoked or expired" do
    invite.revoke!
    assert invite.persisted?

    Invitation.last.update_columns(expires_at: 1.minute.ago)
    assert invite.persisted?
  end

  test "find_pending_by_token ignores unknown, blank, expired, revoked and accepted invitations" do
    expired = invite(email: "a@example.com").tap { |i| i.update_columns(expires_at: 1.minute.ago) }
    revoked = invite(email: "b@example.com").tap(&:revoke!)
    accepted = invite(email: "c@example.com")
    accepted.accept!(password: "password123", password_confirmation: "password123")

    [ "nope", "", nil, expired.token, revoked.token, accepted.token ].each do |token|
      assert_nil Invitation.find_pending_by_token(token), token.inspect
    end
    assert_equal [ :expired, :revoked, :accepted ], [ expired, revoked, accepted.reload ].map(&:status)
  end

  test "accept! creates the account with the invitation's email and role" do
    invitation = invite(role: :operator)

    user = invitation.accept!(password: "password123", password_confirmation: "password123")

    assert_equal [ "dave@example.com", "operator" ], [ user.email, user.role ]
    assert_equal user, invitation.reload.user
    assert_not invitation.pending?
  end

  test "accept! keeps the invitation pending when the password is invalid" do
    invitation = invite

    assert_raises(ActiveRecord::RecordInvalid) { invitation.accept!(password: "short", password_confirmation: "short") }

    assert invitation.reload.pending?
    assert_not User.exists?(email: "dave@example.com")
  end

  test "an invitation cannot be accepted twice" do
    invitation = invite
    invitation.accept!(password: "password123", password_confirmation: "password123")

    assert_raises(ActiveRecord::RecordInvalid) { invitation.accept!(password: "password123", password_confirmation: "password123") }
  end
end
