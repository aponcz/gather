class AuditEvent < ApplicationRecord
  belongs_to :organization
  belongs_to :invite, optional: true
  belongs_to :user, optional: true
  belongs_to :contact, optional: true

  validates :action, presence: true
end
