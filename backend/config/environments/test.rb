Rails.application.configure do
  config.cache_classes = true
  config.eager_load = false
  config.public_file_server.enabled = true
  config.consider_all_requests_local = true
  config.action_mailer.delivery_method = :test
  config.action_mailer.default_url_options = { host: "localhost", port: 3000 }
end
