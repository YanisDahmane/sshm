# Sends an invitation link (see Invitation) when outgoing emails are configured.
class InvitationMailer < ApplicationMailer
  def invite(invitation)
    @invitation = invitation
    @url = invitation_acceptance_url(invitation.token)
    mail to: invitation.email, subject: "Invitation à rejoindre Elio"
  end
end
