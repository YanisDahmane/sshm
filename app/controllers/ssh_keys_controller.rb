class SshKeysController < ApplicationController
  def create
    regenerated = SshKey.exists?
    SshKey.generate!

    notice = if regenerated
      "Nouvelle clé SSH générée. Remplacez l'ancienne clé publique sur vos serveurs."
    else
      "Clé SSH générée. Ajoutez la clé publique sur vos serveurs."
    end
    redirect_to settings_path, notice: notice
  end
end
