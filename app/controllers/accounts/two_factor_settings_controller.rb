# Enabling / disabling 2FA and regenerating backup codes for the signed-in user.
# The secret being set up stays in the session until a code confirms it.
class TwoFactorSettingsController < ApplicationController
  skip_before_action :require_two_factor_setup, only: %i[new create]

  def new
    return redirect_to(account_path, alert: "La double authentification est déjà activée.") if current_user.two_factor_enabled?

    session[:pending_otp_secret] ||= User.generate_otp_secret
    @secret = session[:pending_otp_secret]
    @qr_code = RQRCode::QRCode.new(current_user.otp_provisioning_uri(@secret)).as_svg(module_size: 4, standalone: true, use_path: true)
  end

  def create
    secret = session[:pending_otp_secret]
    return redirect_to(new_two_factor_path) unless secret

    @backup_codes = current_user.enable_two_factor!(secret, params[:code])
    if @backup_codes
      session.delete(:pending_otp_secret)
      Activity.record!(:two_factor_enabled, email: current_user.email)
      flash.now[:notice] = "Double authentification activée."
      render :backup_codes
    else
      redirect_to new_two_factor_path, alert: "Code invalide : vérifiez l'heure de votre téléphone et réessayez."
    end
  end

  def destroy
    if current_user.two_factor_mandatory?
      return redirect_to(account_path, alert: "La double authentification est obligatoire pour votre rôle (#{current_user.role_label.downcase}).")
    end
    return redirect_to(account_path, alert: "Code invalide.") unless current_user.verify_two_factor(params[:code])

    current_user.disable_two_factor!
    Activity.record!(:two_factor_disabled, email: current_user.email)
    redirect_to account_path, notice: "Double authentification désactivée."
  end

  def backup_codes
    return redirect_to(account_path, alert: "Code invalide.") unless current_user.verify_two_factor(params[:code])

    @backup_codes = current_user.regenerate_backup_codes!
    flash.now[:notice] = "Nouveaux codes de secours générés : les anciens ne fonctionnent plus."
    render :backup_codes
  end
end
