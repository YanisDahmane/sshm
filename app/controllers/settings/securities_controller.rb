module Settings
  class SecuritiesController < ApplicationController
    require_permission :administer

    def update
      setting = AppSetting.current
      setting.update!(require_admin_two_factor: params.dig(:app_setting, :require_admin_two_factor) == "1",
                      require_operator_two_factor: params.dig(:app_setting, :require_operator_two_factor) == "1")
      key = { [ true, true ] => :mandatory_both, [ true, false ] => :mandatory_admins, [ false, true ] => :mandatory_operators, [ false, false ] => :optional }
              .fetch([ setting.require_admin_two_factor, setting.require_operator_two_factor ])
      notice = t("flash.security.#{key}")
      redirect_to settings_users_path, notice: notice
    end
  end
end
