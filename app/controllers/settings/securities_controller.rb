module Settings
  class SecuritiesController < ApplicationController
    require_permission :administer

    def update
      setting = AppSetting.current
      setting.update!(require_admin_two_factor: params.dig(:app_setting, :require_admin_two_factor) == "1",
                      require_operator_two_factor: params.dig(:app_setting, :require_operator_two_factor) == "1")
      roles = { "administrateurs" => setting.require_admin_two_factor, "opérateurs" => setting.require_operator_two_factor }.select { |_, on| on }.keys
      notice = roles.any? ? "Double authentification obligatoire pour les #{roles.to_sentence(last_word_connector: " et ")}." : "Double authentification facultative pour tous."
      redirect_to settings_users_path, notice: notice
    end
  end
end
