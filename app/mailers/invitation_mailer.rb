# Sends an invitation link (see Invitation) when outgoing emails are configured.
class InvitationMailer < ApplicationMailer
  def invite(invitation)
    @invitation = invitation
    @url = invitation_acceptance_url(invitation.token)
    # In the language chosen for the invitation.
    I18n.with_locale(invitation.locale || AppSetting.current.default_locale) do
      mail to: invitation.email, subject: t("invitation_mailer.invite.subject")
    end
  end
end
