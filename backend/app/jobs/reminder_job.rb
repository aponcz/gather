class ReminderJob < ApplicationJob
  queue_as :default

  def perform(reminder_id)
    reminder = Reminder.find(reminder_id)
    return unless reminder.scheduled?
    return if reminder.invite.completed? || reminder.invite.cancelled?

    InviteMailer.with(invite: reminder.invite).reminder_email.deliver_now if reminder.email?
    reminder.update!(status: :sent, sent_at: Time.current)
    AuditLogger.log!(company: reminder.invite.company, invite: reminder.invite, action: "reminder.sent", metadata: { channel: reminder.channel })
  rescue StandardError => e
    reminder&.update!(status: :failed, error_message: e.message)
    raise
  end
end
