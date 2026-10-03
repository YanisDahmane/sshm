module Settings
  class InvitationsController < ApplicationController
    require_permission :administer

    def create
      @invitation = Invitation.new(params.expect(invitation: %i[email role]).merge(invited_by: current_user))

      if @invitation.save
        Activity.record!(:user_invited, email: @invitation.email, role_label: @invitation.role_label)
        redirect_to settings_users_path, notice: "Invitation créée pour #{@invitation.email}. Copiez le lien et envoyez-le-lui."
      else
        redirect_to settings_users_path, alert: "Invitation impossible : #{@invitation.errors.full_messages.to_sentence}"
      end
    end

    def destroy
      invitation = Invitation.pending.find(params[:id])
      invitation.revoke!
      Activity.record!(:invitation_revoked, email: invitation.email)
      redirect_to settings_users_path, notice: "L'invitation de #{invitation.email} a été révoquée.", status: :see_other
    end
  end
end
