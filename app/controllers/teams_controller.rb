# Teams of profiles, listed with the profiles. A team's page lists its
# members and grants / revokes them on servers in one go (TeamAccessesController).
class TeamsController < ApplicationController
  require_permission :operate, only: %i[new create edit update destroy]

  before_action :set_team, only: %i[show edit update destroy]

  def index
    @teams = Team.order(:name).includes(:profiles)
  end

  def show
  end

  def new
    @team = Team.new(profile_ids: Array(params[:profile_ids]))
  end

  def create
    @team = Team.new(team_params)

    if @team.save
      Activity.record!(:team_created, team_name: @team.name, profiles: @team.profiles.size)
      redirect_to team_path(@team), notice: "L'équipe « #{@team.name} » a été créée."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @team.update(team_params)
      redirect_to team_path(@team), notice: "L'équipe « #{@team.name} » a été modifiée."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  # Only the team goes: its profiles and their accesses on the servers stay.
  def destroy
    @team.destroy!
    Activity.record!(:team_deleted, team_name: @team.name)
    redirect_to teams_path, notice: "L'équipe « #{@team.name} » a été supprimée. Ses profils et leurs accès n'ont pas été touchés.", status: :see_other
  end

  private

  def set_team
    @team = Team.find(params[:id])
  end

  def team_params
    params.expect(team: [ :name, :description, profile_ids: [] ])
  end
end
