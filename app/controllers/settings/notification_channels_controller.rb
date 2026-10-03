module Settings
  class NotificationChannelsController < ApplicationController
    require_permission :administer

    before_action :set_channel, only: %i[edit update destroy test]

    # New channels receive the warnings and critical activities by default.
    def new
      @channel = NotificationChannel.new(activity_kinds: Activity::KINDS.values.reject { |kind| kind.severity == :info }.map { |kind| kind.key.to_s })
    end

    def create
      @channel = NotificationChannel.new(channel_params)

      if @channel.save
        redirect_to settings_notifications_path, notice: "Le canal « #{@channel.name} » a été ajouté. Envoyez un test pour vérifier."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
    end

    # A blank webhook keeps the current one (it is never sent back to the browser).
    def update
      attributes = channel_params
      attributes.delete(:webhook_url) if attributes[:webhook_url].blank?

      if @channel.update(attributes)
        redirect_to settings_notifications_path, notice: "Le canal « #{@channel.name} » a été modifié."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @channel.destroy!
      redirect_to settings_notifications_path, notice: "Le canal « #{@channel.name} » a été supprimé.", status: :see_other
    end

    def test
      SlackNotifier.deliver_test(@channel)
      @channel.record_delivery!
      redirect_to settings_notifications_path, notice: "Message de test envoyé à « #{@channel.name} »."
    rescue SlackNotifier::DeliveryError => e
      @channel.record_delivery!(error: e.message)
      redirect_to settings_notifications_path, alert: "Échec de l'envoi à « #{@channel.name} » : #{e.message}"
    end

    private

    def set_channel
      @channel = NotificationChannel.find(params[:id])
    end

    def channel_params
      params.expect(notification_channel: [ :name, :webhook_url, :mention_channel, :enabled, activity_kinds: [] ])
    end
  end
end
