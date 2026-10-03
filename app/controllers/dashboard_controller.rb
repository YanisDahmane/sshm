class DashboardController < ApplicationController
  def index
    @servers = Server.order(:name)
  end
end
