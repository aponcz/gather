class ApplicationMailer < ActionMailer::Base
  SENDGRID_TRACKING_SETTINGS = {
    filters: {
      clicktrack: {
        settings: {
          enable: 0,
          enable_text: false
        }
      }
    }
  }.freeze

  default from: ENV.fetch("MAIL_FROM", "no-reply@goprotext.com"),
          "X-SMTPAPI" => SENDGRID_TRACKING_SETTINGS.to_json
end
