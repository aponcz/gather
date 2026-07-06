class DailyUncollectedDocumentsSummaryJob < ApplicationJob
  queue_as :default

  def perform
    invites = Invite
      .includes(:contact, :invite_contacts, :company, request_items: :uploaded_files)
      .where.not(status: %w[completed cancelled])

    invites.find_each do |invite|
      pending_items = invite.request_items.select do |item|
        item.pending? || item.rejected? || item.uploaded_files.empty?
      end
      next if pending_items.empty?
      next if invite.primary_recipient_email.blank?

      InviteMailer.with(invite: invite, pending_items: pending_items).daily_uncollected_summary_email.deliver_now
    end
  end
end
