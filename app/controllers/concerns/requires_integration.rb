# For the pages of an extension: 404 while it is disabled.
module RequiresIntegration
  extend ActiveSupport::Concern

  class_methods do
    def requires_integration(kind)
      before_action { @integration = Integration.find_enabled(kind) || raise(ActionController::RoutingError, "#{kind} disabled") }
    end
  end
end
