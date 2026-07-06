class ImportProtextLoansJob < ApplicationJob
  queue_as :default

  def perform(company_id, user_id, access_token = nil)
    company = Company.find(company_id)
    user = User.find(user_id)
    ProtextLoansImportService.new(company: company, user: user, access_token: access_token).call
  rescue StandardError => e
    Rails.logger.error("ImportProtextLoansJob failed: #{e.class}: #{e.message}")
  end
end
