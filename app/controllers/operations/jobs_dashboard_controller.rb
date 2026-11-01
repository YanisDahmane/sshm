# Base controller of the Mission Control – Jobs dashboard (/jobs): Elio's
# sign-in and admins only, instead of the engine's HTTP basic auth.
class JobsDashboardController < ApplicationController
  require_permission :administer

  private

  # Inside the engine, the app's layout and route helpers are not available.
  def render_forbidden
    redirect_to main_app.root_path, alert: t("jobs_dashboard_controller.forbidden", role_label: current_user.role_label)
  end
end
