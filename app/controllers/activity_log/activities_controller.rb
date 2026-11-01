class ActivitiesController < ApplicationController
  PER_PAGE = 50

  def index
    @category = params[:category].presence_in(Activity::CATEGORIES.map(&:to_s))
    @server = Server.find_by(id: params[:server_id])

    scope = Activity.recent.includes(:user, :server, :public_key)
    scope = scope.in_category(@category) if @category
    scope = scope.where(server: @server) if @server
    @pager = paginate(scope, per_page: PER_PAGE)
    @activities = @pager.records
  end
end
