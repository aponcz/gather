Devise.setup do |config|
  config.mailer_sender = ENV.fetch("DEVISE_MAILER_SENDER", "no-reply@gather.local")
  config.navigational_formats = []
  config.secret_key = ENV["DEVISE_SECRET_KEY"].presence ||
    ENV["SECRET_KEY_BASE"].presence ||
    ENV["JWT_SECRET"].presence ||
    "gather-local-devise-secret-key"

  require "devise/orm/active_record"

  config.password_archiving_count = ENV.fetch("DEVISE_PASSWORD_ARCHIVING_COUNT", "5").to_i
  config.expire_password_after = ENV.fetch("DEVISE_EXPIRE_PASSWORD_AFTER", "90").to_i.days
end
