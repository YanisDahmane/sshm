class DashboardController < ApplicationController
  def index
    @checklist = OnboardingChecklist.new
    @insights = KeyInsights.new
    @servers = Server.order(:name).to_a
    @temporary_accesses = TemporaryAccess.active.includes(:server, :public_key).order(:expires_at)
    @public_keys_count = PublicKey.count
    @activities = Activity.recent.includes(:user, :server, :public_key).limit(8)
  end
end
