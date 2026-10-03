class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  before_action :require_setup
  before_action :authenticate_user!, unless: :devise_controller?
  before_action { Current.user = current_user }
  include Authorization

  layout :layout_by_resource

  private

  # Until the first admin exists, every page leads to the setup page.
  def require_setup
    redirect_to new_setup_path if User.none?
  end

  def layout_by_resource
    devise_controller? ? "auth" : "application"
  end
end
