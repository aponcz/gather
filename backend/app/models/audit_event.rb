class AuditEvent < ApplicationRecord
  belongs_to :company
  belongs_to :invite, optional: true
  belongs_to :user, optional: true
  belongs_to :contact, optional: true

  validates :action, presence: true

  def actor_email
    user&.email || contact&.email
  end
end
