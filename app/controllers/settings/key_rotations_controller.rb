module Settings
  # Replacing SSHM's key without downtime (see KeyRotation), admins only.
  class KeyRotationsController < ApplicationController
    require_permission :administer

    before_action :set_rotation, only: %i[show retry finalize]

    def create
      rotation = KeyRotation.start!(by: current_user)
      Activity.record!(:ssh_key_rotation_started, servers: rotation.servers_count)
      RotateSshKeyJob.perform_later(rotation)
      redirect_to settings_key_rotation_path(rotation), notice: "Rotation de la clé SSHM lancée."
    rescue KeyRotation::AlreadyRunning
      redirect_to settings_path, alert: "Une rotation de la clé est déjà en cours."
    end

    def show
    end

    def retry
      return redirect_to(settings_key_rotation_path(@rotation), alert: "Rien à relancer.") unless @rotation.status == :partial

      @rotation.update!(finished_at: nil)
      RotateSshKeyJob.perform_later(@rotation, retry_failed: true)
      redirect_to settings_key_rotation_path(@rotation), notice: "Relance des serveurs en échec."
    end

    # Activates the new key although some servers failed (they lose SSHM's access).
    def finalize
      return redirect_to(settings_key_rotation_path(@rotation), alert: "Cette rotation ne peut pas être finalisée.") unless @rotation.status == :partial

      @rotation.finish!(force: true)
      redirect_to settings_key_rotation_path(@rotation), notice: "Nouvelle clé activée, l'ancienne est supprimée."
    end

    private

    def set_rotation
      @rotation = KeyRotation.find(params[:id])
    end
  end
end
