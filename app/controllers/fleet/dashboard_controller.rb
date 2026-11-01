class DashboardController < ApplicationController
  # Overview: setup checklist, fleet figures, what needs attention, temporary
  # accesses, systems and recent activity.
  def index
    @checklist = OnboardingChecklist.new
    @servers = Server.order(:name).includes(:inventory_snapshots).to_a
    @summary = FleetSummary.new(@servers)
    @insights = KeyInsights.new
    @attention = AttentionList.new(@servers, insights: @insights, summary: @summary)
    @temporary_accesses = TemporaryAccess.active.includes(:server, :public_key).order(:expires_at)
    @systems = @servers.filter_map(&:os_name).tally.sort_by { |name, count| [ -count, name ] }
    @public_keys_count = PublicKey.count
    @activities = Activity.recent.includes(:user, :server, :public_key).limit(8)
  end
end
