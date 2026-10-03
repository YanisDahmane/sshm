module Settings
  # Placeholder: will let users choose which activity kinds notify them.
  class NotificationsController < ApplicationController
    def show
      @kinds_by_category = Activity::KINDS.values.group_by(&:category)
    end
  end
end
