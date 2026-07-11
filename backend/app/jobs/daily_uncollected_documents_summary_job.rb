class DailyUncollectedDocumentsSummaryJob < ApplicationJob
  queue_as :default

  def perform
    loans = Loan
      .includes(:contact, :loan_contacts, :company, request_items: :uploaded_files)
      .where.not(status: %w[completed cancelled])

    loans.find_each do |loan|
      pending_items = loan.request_items.select do |item|
        item.pending? || item.rejected? || item.uploaded_files.empty?
      end
      next if pending_items.empty?
      next if loan.primary_recipient_email.blank?

      LoanMailer.with(loan: loan, pending_items: pending_items).daily_uncollected_summary_email.deliver_now
    end
  end
end
