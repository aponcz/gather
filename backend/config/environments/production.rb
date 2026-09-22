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
    address: ENV["SMTP_ADDRESS"],
    port: ENV.fetch("SMTP_PORT", 587),
    user_name: ENV["SMTP_USERNAME"],
    password: ENV["SMTP_PASSWORD"],
    authentication: :plain,
    enable_starttls_auto: true
  }
  config.action_mailer.delivery_method = :smtp if ENV["SMTP_ADDRESS"].present?
end
