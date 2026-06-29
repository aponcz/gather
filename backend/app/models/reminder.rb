class Reminder < ApplicationRecord
  belongs_to :invite

  enum channel: { email: "email", sms: "sms" }
  enum status: { scheduled: "scheduled", sent: "sent", failed: "failed", cancelled: "cancelled" }

  validates :send_at, :channel, presence: true
end
