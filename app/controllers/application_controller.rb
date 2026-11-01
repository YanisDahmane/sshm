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
  include Throttled

  layout :layout_by_resource

  private

  # One page of a list (?page=), see Paginator and shared/_pagination.
  def paginate(collection, per_page:)
    Paginator.new(collection, page: params[:page], per_page: per_page)
  end

  def set_current_user
    Current.user = current_user
  end

  # Admins and operators must enable 2FA first when the settings require it.
  def require_two_factor_setup
    return unless current_user&.two_factor_required?

    redirect_to main_app.account_path, alert: "La double authentification est obligatoire pour votre rôle : activez-la pour continuer."
  end

  # Until the first admin exists, every page leads to the setup page.
  def require_setup
    redirect_to main_app.new_setup_path if User.none?
  end

  def layout_by_resource
    devise_controller? ? "auth" : "application"
  end
end
