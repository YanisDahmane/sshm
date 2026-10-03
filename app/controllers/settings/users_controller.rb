module Settings
  class UsersController < ApplicationController
    require_permission :administer

    def index
      @users = User.order(:email)
      @invitations = Invitation.pending.includes(:invited_by).order(created_at: :desc)
      @invitation = Invitation.new
    end
  end
end
