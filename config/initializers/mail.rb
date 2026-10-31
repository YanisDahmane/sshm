# Outgoing emails (password reset, invitations), configured by environment
# variables: SMTP_ADDRESS (enables sending), SMTP_PORT (587), SMTP_USERNAME,
# SMTP_PASSWORD, SMTP_AUTHENTICATION (plain), ELIO_HOST (host of the links in
# the emails) and ELIO_MAIL_FROM (sender). Without SMTP_ADDRESS, nothing is
# sent and the "forgot password" link is hidden.
Rails.application.configure do
  config.x.mail_enabled = Rails.env.test? || ENV["SMTP_ADDRESS"].present?

  if ENV["SMTP_ADDRESS"].present?
    config.action_mailer.delivery_method = :smtp
    config.action_mailer.raise_delivery_errors = true
    config.action_mailer.smtp_settings = {
      address: ENV["SMTP_ADDRESS"],
      port: Integer(ENV.fetch("SMTP_PORT", 587)),
      user_name: ENV["SMTP_USERNAME"].presence,
      password: ENV["SMTP_PASSWORD"].presence,
      authentication: ENV.fetch("SMTP_AUTHENTICATION", "plain").to_sym,
      enable_starttls_auto: true,
      open_timeout: 5,
      read_timeout: 10
    }.compact
  end

  if ENV["ELIO_HOST"].present?
    config.action_mailer.default_url_options = { host: ENV["ELIO_HOST"], protocol: Rails.env.production? ? "https" : "http" }
  end
end
