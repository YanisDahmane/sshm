# An interface language attribute (users, invitations, notification
# channels, the instance): one of Elio::Locales.available, or nil when
# allowed (blank is stored as nil).
module Localized
  extend ActiveSupport::Concern

  class_methods do
    def localized(attribute = :locale, allow_nil: true)
      normalizes attribute, with: ->(value) { value.presence }
      validates attribute, inclusion: { in: ->(_) { Elio::Locales.available.map(&:to_s) } }, allow_nil: allow_nil
    end
  end
end
