class SettingsController < ApplicationController
  def show
    @ssh_key = SshKey.current
  end
end
