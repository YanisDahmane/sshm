class ApplicationMailer < ActionMailer::Base
  default from: ENV.fetch("ELIO_MAIL_FROM", "elio@localhost")
  layout "mailer"
end
