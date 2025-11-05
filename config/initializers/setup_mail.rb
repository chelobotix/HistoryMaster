ActionMailer::Base.smtp_settings = {
  address: ENV["MAILJET_SERVER"],
  port: ENV["MAILJET_PORT"],
  user_name: ENV["MAILJET_API_KEY"],
  password: ENV["MAILJET_API_SECRET"],
  authentication: "plain",
  enable_starttls_auto: true
}
