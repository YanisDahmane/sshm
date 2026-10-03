module Settings
  class UsersController < ApplicationController
    require_permission :administer

    before_action :set_user, only: %i[update deactivate reactivate reset_two_factor]

    def index
      @users = User.includes(:profile).order(:email)
      @invitations = Invitation.pending.includes(:invited_by).order(created_at: :desc)
      @invitation = Invitation.new
      @profiles = Profile.order(:name)
      @setting = AppSetting.current
    end

    # Role and linked profile.
    def update
      previous_role = @user.role_label

      if @user.update(params.expect(user: %i[role profile_id]))
        if @user.saved_change_to_role?
          Activity.record!(:user_role_changed, email: @user.email, from: previous_role, to: @user.role_label)
        end
        redirect_to settings_users_path, notice: "#{@user.email} a été mis à jour."
      else
        redirect_to settings_users_path, alert: "Impossible de modifier #{@user.email} : #{@user.errors.full_messages.to_sentence}"
      end
    end

    def deactivate
      return redirect_to(settings_users_path, alert: "Vous ne pouvez pas désactiver votre propre compte.") if @user == current_user

      @user.deactivate!
      Activity.record!(:user_deactivated, email: @user.email)
      redirect_to settings_users_path, notice: "#{@user.email} est désactivé : il ne peut plus se connecter."
    rescue ActiveRecord::RecordInvalid
      redirect_to settings_users_path, alert: @user.errors.full_messages.to_sentence
    end

    def reactivate
      @user.reactivate!
      Activity.record!(:user_reactivated, email: @user.email)
      redirect_to settings_users_path, notice: "#{@user.email} peut de nouveau se connecter."
    end

    # For someone who lost their authenticator and backup codes.
    def reset_two_factor
      @user.disable_two_factor!
      Activity.record!(:two_factor_disabled, email: @user.email, reset_by: current_user.email)
      redirect_to settings_users_path, notice: "La double authentification de #{@user.email} est réinitialisée."
    end

    private

    def set_user
      @user = User.find(params[:id])
    end
  end
end
