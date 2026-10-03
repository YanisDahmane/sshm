class ProfilesController < ApplicationController
  require_permission :operate, only: %i[new create edit update destroy]

  before_action :set_profile, only: %i[show edit update destroy]

  def index
    @profiles = Profile.order(:name)
  end

  def show
  end

  # Can be prefilled (e.g. from a server's key without profile) with
  # `public_key`, `name` and a local `return_to` path.
  def new
    @profile = Profile.new(name: params[:name], public_key: params[:public_key])
    @return_to = safe_return_to
  end

  def create
    @profile = Profile.new(profile_params)

    @return_to = safe_return_to

    if @profile.save
      Activity.record!(:profile_created, profile: @profile, fingerprint: @profile.fingerprint)
      redirect_to @return_to || profile_path(@profile), notice: "Le profil « #{@profile.name} » a été ajouté."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @profile.update(profile_params)
      redirect_to profile_path(@profile), notice: "Le profil « #{@profile.name} » a été modifié."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @profile.destroy!
    Activity.record!(:profile_deleted, profile_name: @profile.name, fingerprint: @profile.fingerprint)
    redirect_to profiles_path, notice: "Le profil « #{@profile.name} » a été supprimé.", status: :see_other
  end

  private

  # Only local paths, to avoid redirecting to another site.
  def safe_return_to
    path = params[:return_to].to_s
    path if path.start_with?("/") && !path.start_with?("//") && !path.include?("\\")
  end

  def set_profile
    @profile = Profile.find(params[:id])
  end

  def profile_params
    params.expect(profile: [ :name, :public_key ])
  end
end
