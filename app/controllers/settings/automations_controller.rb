module Settings
  class AutomationsController < ApplicationController
    require_permission :administer

    before_action :set_automation, only: %i[update run]

    def index
      @automations = Automation.available
      @groups = ServerGroup.order(:name)
    end

    def update
      if @automation.update(automation_params)
        state = @automation.enabled? ? "activée (#{Automation::INTERVALS.fetch(@automation.interval_minutes).downcase}, #{@automation.scope_label.downcase_first})" : "désactivée"
        redirect_to settings_automations_path, notice: "« #{@automation.label} » #{state}."
      else
        redirect_to settings_automations_path, alert: @automation.errors.full_messages.to_sentence
      end
    end

    def run
      task, started = @automation.start_now!(user: current_user)
      redirect_to task_path(task), notice: started ? "« #{@automation.label} » lancée." : "Déjà en cours : voici la tâche en cours."
    end

    private

    def set_automation
      @automation = Automation.find(params[:id])
    end

    def automation_params
      params.expect(automation: [ :enabled, :interval_minutes, server_group_ids: [] ])
    end
  end
end
