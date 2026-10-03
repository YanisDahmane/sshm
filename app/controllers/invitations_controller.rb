# Accepting an invitation (public page reached through the invitation link).
class InvitationsController < ApplicationController
  layout "auth"

  skip_before_action :authenticate_user!, :authorize_view!
  before_action :redirect_signed_in_user
  before_action :set_invitation

  def show
    @user = User.new(email: @invitation.email)
  end

  def accept
    passwords = params.expect(user: %i[password password_confirmation])
    @user = @invitation.accept!(password: passwords[:password], password_confirmation: passwords[:password_confirmation])
    Activity.record!(:invitation_accepted, user: @user, email: @user.email, role_label: @user.role_label)

    sign_in(@user)
    redirect_to root_path, notice: "Bienvenue sur SSHM !"
  rescue ActiveRecord::RecordInvalid => e
    @user = e.record.is_a?(User) ? e.record : User.new(email: @invitation.email)
    render :show, status: :unprocessable_entity
  end

  private

  def redirect_signed_in_user
    redirect_to root_path, alert: "Vous êtes déjà connecté : déconnectez-vous pour accepter cette invitation." if user_signed_in?
  end

  def set_invitation
    @invitation = Invitation.find_pending_by_token(params[:token])
    render :invalid, status: :not_found unless @invitation
  end
end
