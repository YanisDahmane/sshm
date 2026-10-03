# First launch: creates the first admin account, then disappears.
class SetupsController < ApplicationController
  layout "auth"

  skip_before_action :require_setup, :authenticate_user!, :authorize_view!
  before_action { raise ActionController::RoutingError, "Setup already done" if User.exists? }

  def new
    @user = User.new
  end

  def create
    @user = User.new(params.expect(user: %i[email password password_confirmation]).merge(role: :admin))

    if @user.save
      sign_in(@user)
      redirect_to root_path, notice: "Bienvenue ! Votre compte administrateur est créé."
    else
      render :new, status: :unprocessable_entity
    end
  end
end
