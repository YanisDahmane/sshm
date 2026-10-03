# Differences between the access rules and the keys last read on the servers.
class DriftsController < ApplicationController
  def show
    @report = DriftDetector.call
  end
end
