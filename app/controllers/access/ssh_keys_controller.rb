class SshKeysController < ApplicationController
  require_permission :administer

  def create
    regenerated = SshKey.exists?
    SshKey.generate!
    Activity.record!(:ssh_key_generated, regenerated: regenerated)

    notice = if regenerated
      t("ssh_keys_controller.regenerated")
    else
      t("ssh_keys_controller.generated")
    end
    redirect_to settings_path, notice: notice
  end
end
