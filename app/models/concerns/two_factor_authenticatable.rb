# Time-based one-time passwords (TOTP, RFC 6238) with single-use backup codes.
# A code is never accepted twice (otp_last_used_at), backup codes are stored as
# HMAC digests and consumed when used.
module TwoFactorAuthenticatable
  extend ActiveSupport::Concern

  ISSUER = "SSHM".freeze
  DRIFT = 30 # seconds of clock drift accepted on each side
  BACKUP_CODES_COUNT = 10

  included do
    encrypts :otp_secret
  end

  class_methods do
    def generate_otp_secret = ROTP::Base32.random
  end

  def two_factor_enabled? = otp_enabled_at.present?

  def otp_provisioning_uri(secret) = ROTP::TOTP.new(secret, issuer: ISSUER).provisioning_uri(email)

  def backup_codes_left = otp_backup_codes.size

  # Enables 2FA once a code from the authenticator app confirms `secret`.
  # Returns the backup codes to show (once), or nil when the code is wrong.
  def enable_two_factor!(secret, code)
    timestep = ROTP::TOTP.new(secret, issuer: ISSUER).verify(normalize_totp(code), drift_behind: DRIFT, drift_ahead: DRIFT)
    return unless timestep

    codes = generate_backup_codes
    update!(otp_secret: secret, otp_enabled_at: Time.current, otp_last_used_at: timestep, otp_backup_codes: codes.map { |c| backup_code_digest(c) })
    codes
  end

  def disable_two_factor!
    update!(otp_secret: nil, otp_enabled_at: nil, otp_last_used_at: nil, otp_backup_codes: [])
  end

  # Checks a TOTP code (never the same twice) or consumes a backup code.
  # Returns :totp, :backup_code or nil.
  def verify_two_factor(code)
    return unless two_factor_enabled? && code.present?

    if normalize_totp(code).match?(/\A\d{6}\z/)
      timestep = ROTP::TOTP.new(otp_secret, issuer: ISSUER).verify(normalize_totp(code), drift_behind: DRIFT, drift_ahead: DRIFT, after: otp_last_used_at)
      return unless timestep

      update_column(:otp_last_used_at, timestep)
      :totp
    else
      digest = backup_code_digest(code)
      match = otp_backup_codes.find { |stored| ActiveSupport::SecurityUtils.secure_compare(stored, digest) }
      return unless match

      update_column(:otp_backup_codes, otp_backup_codes - [ match ])
      :backup_code
    end
  end

  # New backup codes (the previous ones stop working). Returns them to show once.
  def regenerate_backup_codes!
    codes = generate_backup_codes
    update!(otp_backup_codes: codes.map { |code| backup_code_digest(code) })
    codes
  end

  private

  def normalize_totp(code) = code.to_s.gsub(/\s/, "")

  def generate_backup_codes
    Array.new(BACKUP_CODES_COUNT) { SecureRandom.hex(5).scan(/.{5}/).join("-") }
  end

  def backup_code_digest(code)
    OpenSSL::HMAC.hexdigest("SHA256", Rails.application.secret_key_base, code.to_s.downcase.gsub(/[^0-9a-f]/, ""))
  end
end
