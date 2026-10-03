# Role-based access (see User::PERMISSIONS). Every controller declares the
# permission its actions need; anything not declared requires :view.
#
#   require_permission :operate, only: %i[new create]
module Authorization
  extend ActiveSupport::Concern

  class NotAuthorized < StandardError; end

  included do
    before_action :authorize_view!, unless: :devise_controller?
    rescue_from NotAuthorized, with: :render_forbidden
    helper_method :can?
  end

  class_methods do
    def require_permission(permission, **options)
      before_action(-> { authorize!(permission) }, **options)
    end
  end

  private

  def can?(permission) = current_user&.can?(permission) || false

  def authorize_view! = authorize!(:view)

  def authorize!(permission)
    raise NotAuthorized unless can?(permission)
  end

  def render_forbidden
    message = "Votre rôle (#{current_user.role_label}) ne permet pas cette action."

    respond_to do |format|
      format.turbo_stream do
        flash.now[:alert] = message
        render turbo_stream: turbo_stream.update("flash", partial: "shared/flash"), status: :forbidden
      end
      format.html do
        if turbo_frame_request?
          render html: helpers.turbo_frame_tag(request.headers["Turbo-Frame"]) { helpers.tag.p(message, class: "forbidden py-4 text-sm text-red-700") }, status: :forbidden
        else
          render "errors/forbidden", locals: { message: message }, status: :forbidden
        end
      end
      format.any { head :forbidden }
    end
  end
end
