class SettingsController < ApplicationController
  require_permission :administer

  def show
    @ssh_key = SshKey.current
  end
end
