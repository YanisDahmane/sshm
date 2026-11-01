module Settings
  # The default language of the instance: for users who have not chosen one
  # and whose browser asks for a language Elio does not have, for the jobs
  # (task results, errors) and the notification channels without a language.
  class LanguagesController < ApplicationController
    require_permission :administer

    def update
      setting = AppSetting.current
      if setting.update(params.expect(app_setting: [ :default_locale ]))
        redirect_to settings_path(anchor: "language"), notice: t(".saved")
      else
        redirect_to settings_path(anchor: "language"), alert: t(".invalid")
      end
    end
  end
end
