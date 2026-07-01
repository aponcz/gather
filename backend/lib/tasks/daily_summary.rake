namespace :gather do
  desc "Send daily summary emails for uncollected documents"
  task send_daily_uncollected_documents_summary: :environment do
    DailyUncollectedDocumentsSummaryJob.perform_now
  end
end
