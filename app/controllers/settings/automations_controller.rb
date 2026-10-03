module Settings
  class AutomationsController < ApplicationController
    before_action :set_automation, only: %i[update run]

    def index
      @automations = Automation.all_kinds
    end

    def update
      if @automation.update(automation_params)
        state = @automation.enabled? ? "activée (#{Automation::INTERVALS.fetch(@automation.interval_minutes).downcase})" : "désactivée"
        redirect_to settings_automations_path, notice: "« #{@automation.label} » #{state}."
      else
        redirect_to settings_automations_path, alert: @automation.errors.full_messages.to_sentence
      end
    end

    def run
      RunAutomationJob.perform_later(@automation)
      redirect_to settings_automations_path, notice: "« #{@automation.label} » lancée. Le résultat apparaîtra dans l'activité."
    end

    private

    def set_automation
      @automation = Automation.find(params[:id])
    end

    def automation_params
      params.expect(automation: [ :enabled, :interval_minutes ])
    end
  end
end
