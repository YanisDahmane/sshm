require "test_helper"

class InvitationMailerTest < ActionMailer::TestCase
  test "sends the personal link with the role and the expiry" do
    invitation = Invitation.create!(email: "dave@example.com", role: "operator", invited_by: users(:one))

    mail = InvitationMailer.invite(invitation)

    assert_equal [ "dave@example.com" ], mail.to
    assert_equal "Invitation à rejoindre Elio", mail.subject
    assert_match "one@example.com vous invite à rejoindre Elio", mail.text_part.body.to_s
    assert_match "Opérateur", mail.html_part.body.to_s
    assert_match "http://example.com/invitations/#{invitation.token}", mail.text_part.body.to_s
  end
end
