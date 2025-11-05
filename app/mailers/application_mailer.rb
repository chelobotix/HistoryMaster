class ApplicationMailer < ActionMailer::Base
  default from: ENV["MAILJET_CONFIRMATION_EMAIL"]
  layout "mailer"
end
