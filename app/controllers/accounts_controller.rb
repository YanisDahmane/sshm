# "Mon compte": password and two-factor authentication of the signed-in user.
class AccountsController < ApplicationController
  skip_before_action :require_two_factor_setup

  def show
  end

  def password
    if current_user.update_with_password(params.expect(user: %i[current_password password password_confirmation]))
      bypass_sign_in(current_user)
      redirect_to account_path, notice: "Mot de passe modifié."
    else
      render :show, status: :unprocessable_entity
    end
  end
end
