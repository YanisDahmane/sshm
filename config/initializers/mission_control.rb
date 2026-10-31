# Technical view of the background jobs (Solid Queue), for admins only, with
# Elio's sign-in instead of HTTP basic auth: see JobsDashboardController.
# (The module attributes are set directly: the engine copies
# config.mission_control.jobs before the app initializers run.)
MissionControl::Jobs.base_controller_class = "JobsDashboardController"
MissionControl::Jobs.http_basic_auth_enabled = false

# Mission Control restricts I18n to :en during its requests: if the
# translations were first loaded then (first request after a boot = /jobs),
# the French ones would be dropped for the whole process. Load them at boot.
Rails.application.config.after_initialize do
  I18n.backend.eager_load! if I18n.backend.respond_to?(:eager_load!)
end
