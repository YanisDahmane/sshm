# Per-IP rate limits of the public pages (sign in, password reset,
# invitation, first setup, 2FA): Rails' rate_limit, with a store that also
# works where the cache keeps nothing (tests), and a French message.
module Throttled
  extend ActiveSupport::Concern

  STORE = Rails.cache.is_a?(ActiveSupport::Cache::NullStore) ? ActiveSupport::Cache::MemoryStore.new : Rails.cache

  class_methods do
    # `to` requests per IP `within` the period; then back to `redirect` (a
    # route helper name) with a message, 429.
    def throttle(only:, to:, within:, redirect:, message: "Trop de tentatives : réessayez dans quelques minutes.")
      rate_limit to: to, within: within, only: only, store: STORE, name: "#{controller_path}##{Array(only).join(",")}",
                 with: -> { redirect_to main_app.public_send(redirect), alert: message, status: :see_other }
    end
  end
end
