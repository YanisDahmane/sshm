# Password reset: the request always gets the same answer, so it never tells
# whether an email has an account (Devise's paranoid mode is not used
# globally, it would hide the lockable warnings of the sign-in form).
class Users::PasswordsController < Devise::PasswordsController
  def create
    resource_class.send_reset_password_instructions(resource_params)
    redirect_to new_session_path(resource_name), notice: t("devise.passwords.send_paranoid_instructions")
  end
end
