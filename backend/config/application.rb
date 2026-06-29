require_relative "boot"
require "rails/all"

Bundler.require(*Rails.groups)

module FileInviteBackendRails
  class Application < Rails::Application
    config.load_defaults 7.1
    config.api_only = true
    config.active_job.queue_adapter = :sidekiq
    config.time_zone = "UTC"
    config.middleware.insert_before 0, Rack::Cors do
      allow do
        origins ENV.fetch("CORS_ORIGINS", "*").split(",")
        resource "*", headers: :any, methods: %i[get post put patch delete options head]
      end
    end
  end
end
