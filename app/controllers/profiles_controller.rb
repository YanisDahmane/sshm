class ProfilesController < ApplicationController
  before_action :set_profile, only: %i[show edit update destroy]

  def show
  end

  def new
    @profile = Profile.new
  end

  def create
    @profile = Profile.new(profile_params)

    if @profile.save
      redirect_to root_path, notice: "Le profil « #{@profile.name} » a été ajouté."
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
    redirect_to root_path, notice: "Le profil « #{@profile.name} » a été supprimé.", status: :see_other
  end

  private

  def set_profile
    @profile = Profile.find(params[:id])
  end

  def profile_params
    params.expect(profile: [ :name, :public_key ])
  end
end
