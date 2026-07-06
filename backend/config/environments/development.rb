Rails.application.configure do
  config.enable_reloading = true
  config.eager_load = false
  config.consider_all_requests_local = true
  config.server_timing = true
  config.log_level = :error
  if ENV["RAILS_LOG_TO_STDOUT"].present?
    logger = ActiveSupport::Logger.new(STDOUT)
    logger.formatter = config.log_formatter
    config.logger = ActiveSupport::TaggedLogging.new(logger)
  end
  config.active_storage.service = :local if defined?(ActiveStorage)
  config.action_mailer.delivery_method = :letter_opener rescue nil
  config.action_mailer.default_url_options = { host: "localhost", port: 3000 }
  config.active_storage.service = :minio
end
