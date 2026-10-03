class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  before_action :authenticate_user!, unless: :devise_controller?

  layout :layout_by_resource

  private

  def layout_by_resource
    devise_controller? ? "auth" : "application"
  end
end
