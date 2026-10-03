class SettingsController < ApplicationController
  require_permission :administer

  def show
    @ssh_key = SshKey.current
    @rotation = KeyRotation.in_progress
  end
end
