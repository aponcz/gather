class ReminderJob < ApplicationJob
  queue_as :default

  def perform(reminder_id)
    reminder = Reminder.find(reminder_id)
    return unless reminder.scheduled?
    return if reminder.loan.completed? || reminder.loan.cancelled?

    LoanMailer.with(loan: reminder.loan).reminder_email.deliver_now if reminder.email?
    reminder.update!(status: :sent, sent_at: Time.current)
    AuditLogger.log!(company: reminder.loan.company, loan: reminder.loan, action: "reminder.sent", metadata: { channel: reminder.channel })
  rescue StandardError => e
    reminder&.update!(status: :failed, error_message: e.message)
    raise
  end
end
