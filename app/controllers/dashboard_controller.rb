class DashboardController < ApplicationController
  def index
    @checklist = OnboardingChecklist.new
    @insights = KeyInsights.new
    @servers = Server.order(:name).to_a
    @temporary_accesses = TemporaryAccess.active.includes(:server, :profile).order(:expires_at)
    @profiles_count = Profile.count
    @activities = Activity.recent.includes(:user, :server, :profile).limit(8)
  end
end
