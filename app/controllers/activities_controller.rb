class ActivitiesController < ApplicationController
  PER_PAGE = 50

  def index
    @category = params[:category].presence_in(Activity::CATEGORIES.keys.map(&:to_s))
    @server = Server.find_by(id: params[:server_id])
    @page = [ params[:page].to_i, 1 ].max

    scope = Activity.recent.includes(:user, :server, :profile)
    scope = scope.in_category(@category) if @category
    scope = scope.where(server: @server) if @server
    @activities = scope.offset((@page - 1) * PER_PAGE).limit(PER_PAGE + 1).to_a
    @more = @activities.size > PER_PAGE
    @activities = @activities.first(PER_PAGE)
  end
end
