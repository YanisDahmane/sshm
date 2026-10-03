module Settings
  class SecuritiesController < ApplicationController
    require_permission :administer

    def update
      setting = AppSetting.current
      setting.update!(require_admin_two_factor: params.dig(:app_setting, :require_admin_two_factor) == "1")
      state = setting.require_admin_two_factor ? "obligatoire" : "facultative"
      redirect_to settings_users_path, notice: "La double authentification est désormais #{state} pour les administrateurs."
    end
  end
end
