require "test_helper"

class PasswordResetTest < ActionDispatch::IntegrationTest
  include ActionMailer::TestHelper
  include TwoFactorHelpers

  test "the sign in page links to the password reset when emails can be sent" do
    get new_user_session_path
    assert_select "a.forgot-password[href=?]", new_user_password_path

    Rails.configuration.x.mail_enabled = false
    get new_user_session_path
    assert_select "a.forgot-password", 0
  ensure
    Rails.configuration.x.mail_enabled = true
  end

  test "asking for a link never tells whether the email has an account" do
    get new_user_password_path
    assert_select "form[action=?] input[name='user[email]']", user_password_path

    assert_emails(1) { post user_password_path, params: { user: { email: "one@example.com" } } }
    known = flash[:notice]
    assert_emails(0) { post user_password_path, params: { user: { email: "nobody@example.com" } } }

    assert_equal known, flash[:notice]
    assert_redirected_to new_user_session_path
  end

  test "the emailed link sets a new password, without signing in (the second factor stays required)" do
    user = users(:one)
    enable_two_factor(user)
    post user_password_path, params: { user: { email: user.email } }
    token = ActionMailer::Base.deliveries.last.body.encoded[/reset_password_token=([^"&\s]+)/, 1]
    assert token

    get edit_user_password_path(reset_password_token: token)
    assert_select "input[type=password][name='user[password]']"

    put user_password_path, params: { user: { reset_password_token: token, password: "new-password-42", password_confirmation: "new-password-42" } }

    assert_redirected_to new_user_session_path
    assert user.reload.valid_password?("new-password-42")
    get root_path
    assert_redirected_to new_user_session_path
  end

  test "an invalid token is refused" do
    put user_password_path, params: { user: { reset_password_token: "nope", password: "new-password-42", password_confirmation: "new-password-42" } }

    assert_response :unprocessable_entity
    assert_not users(:one).reload.valid_password?("new-password-42")
  end
end
