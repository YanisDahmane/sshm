# Second step of the sign in for accounts with 2FA (see Users::SessionsController):
# a code from the authenticator app or a backup code, within TIMEOUT.
class TwoFactorChallengesController < ApplicationController
  include Devise::Controllers::Rememberable

  TIMEOUT = 5.minutes

  layout "auth"

  skip_before_action :authenticate_user!, :authorize_view!
  before_action :set_pending_user
  rate_limit to: 10, within: 1.minute, only: :create, with: -> { abandon("Trop de tentatives : reconnectez-vous.") }

  def new
  end

  def create
    method = @user.verify_two_factor(params[:code])
    unless method
      @user.register_failed_two_factor_attempt!
      return abandon("Trop d'essais ratés : votre compte est verrouillé pendant 15 minutes.") if @user.access_locked?

      return render(:new, status: :unprocessable_entity)
    end

    @user.update_column(:failed_attempts, 0)
    remember = session.dig(:two_factor, "remember")
    session.delete(:two_factor)
    sign_in(:user, @user)
    remember_me(@user) if remember
    if method == :backup_code
      Activity.record!(:two_factor_backup_code_used, user: @user, email: @user.email, left: @user.backup_codes_left)
    end

    redirect_to after_sign_in_path_for(@user), notice: "Connexion réussie."
  end

  private

  def set_pending_user
    pending = session[:two_factor] || {}
    @user = User.find_by(id: pending["user_id"])
    expired = pending["started_at"].to_i < TIMEOUT.ago.to_i

    abandon("Session de connexion expirée : reconnectez-vous.") if @user.nil? || expired || !@user.active_for_authentication? || !@user.two_factor_enabled? || @user.access_locked?
  end

  def abandon(message)
    session.delete(:two_factor)
    redirect_to new_user_session_path, alert: message
  end
end
