class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  before_action :require_setup
  before_action :authenticate_user!, unless: :devise_controller?
  # Not in Devise controllers: during the sign in, current_user would
  # authenticate (and store) the user from the form before the 2FA step.
  before_action :set_current_user, unless: :devise_controller?
  before_action :require_two_factor_setup, unless: :devise_controller?
  include Authorization

  layout :layout_by_resource

  private

  def set_current_user
    Current.user = current_user
  end

  # Admins must enable 2FA first when the setting requires it.
  def require_two_factor_setup
    return unless current_user&.two_factor_required?

    redirect_to account_path, alert: "La double authentification est obligatoire pour les administrateurs : activez-la pour continuer."
  end

  # Until the first admin exists, every page leads to the setup page.
  def require_setup
    redirect_to new_setup_path if User.none?
  end

  def layout_by_resource
    devise_controller? ? "auth" : "application"
  end
end
