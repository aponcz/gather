redis_url = ENV.fetch("REDIS_URL", "redis://redis:6379/0")
Sidekiq.configure_server do |config|
  config.redis = { url: redis_url }

  daily_summary_cron = ENV.fetch("DAILY_SUMMARY_CRON", "0 13 * * *")
  schedule_hash = {
    "daily_uncollected_documents_summary" => {
      class: "DailyUncollectedDocumentsSummaryJob",
      queue: "default",
      cron: daily_summary_cron,
      description: "Send daily summary emails for uncollected documents"
    }
  }
  Sidekiq::Cron::Job.load_from_hash!(schedule_hash)
end
Sidekiq.configure_client { |config| config.redis = { url: redis_url } }
