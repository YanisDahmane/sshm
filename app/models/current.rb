# Request-scoped attributes: the signed-in user, recorded as the author of
# activities (nil in jobs and automations, shown as "Système").
class Current < ActiveSupport::CurrentAttributes
  attribute :user
end
