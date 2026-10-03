# Desired state: the access rules, listed for everyone, managed by operators.
# Removing a rule never touches the servers.
class AccessRulesController < ApplicationController
  require_permission :operate, only: %i[create destroy]

  def index
    @rules = AccessRule.includes(:profile, :team, :server, :server_group, :created_by).order(:created_at)
    @rule = AccessRule.new
    @report = DriftDetector.call
  end

  def create
    @rule = AccessRule.new(rule_params.merge(created_by: current_user))

    if @rule.save
      Activity.record!(:access_rule_created, profile: @rule.profile, server: @rule.server, rule: @rule.summary)
      redirect_to access_rules_path, notice: "Règle ajoutée : #{@rule.summary}. Consultez les écarts pour l'appliquer."
    else
      @rules = AccessRule.includes(:profile, :team, :server, :server_group, :created_by).order(:created_at)
      @report = DriftDetector.call
      render :index, status: :unprocessable_entity
    end
  end

  def destroy
    rule = AccessRule.find(params[:id])
    rule.destroy!
    Activity.record!(:access_rule_deleted, profile: rule.profile, server: rule.server, rule: rule.summary)
    redirect_to access_rules_path, notice: "Règle supprimée : #{rule.summary}. Les clés déjà installées restent en place.", status: :see_other
  end

  private

  def rule_params
    params.expect(access_rule: [ :subject_key, :target_key, :unix_user ])
  end
end
