module TwoFactorHelpers
  # Enables 2FA for `user` and returns its backup codes.
  def enable_two_factor(user)
    secret = User.generate_otp_secret
    user.enable_two_factor!(secret, ROTP::TOTP.new(secret).now)
  end

  # A valid code not used yet (the enabling code's time step is already consumed).
  def next_totp(user, offset: 30.seconds)
    ROTP::TOTP.new(user.reload.otp_secret).at(Time.current + offset)
  end
end
