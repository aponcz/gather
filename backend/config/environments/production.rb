Rails.application.configure do
  config.cache_classes = true
  config.eager_load = true
  config.consider_all_requests_local = false
  config.public_file_server.enabled = ENV["RAILS_SERVE_STATIC_FILES"].present?
  config.force_ssl = ENV.fetch("FORCE_SSL", "true") == "true"
  # Allow load balancer health probes over HTTP without redirecting to HTTPS.
  config.ssl_options = {
    redirect: { exclude: ->(request) { request.path == "/health-check" } }
  }
  config.log_level = ENV.fetch("RAILS_LOG_LEVEL", "info")
  config.action_mailer.smtp_settings = {
    address: "smtp.sendgrid.net",
    port: "587",
    authentication: :plain,
    user_name: ENV["SENDGRID_USERNAME"],
    password: ENV["SENDGRID_PASSWORD"],
    domain: "goprotext.com",
    enable_starttls_auto: true
  }
  config.action_mailer.delivery_method = :smtp
end