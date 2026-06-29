class User < ApplicationRecord
  has_secure_password

  belongs_to :organization
  has_many :audit_events, dependent: :nullify

  enum role: { admin: "admin", member: "member", reviewer: "reviewer" }

  validates :email, presence: true, uniqueness: { scope: :organization_id }, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :name, presence: true
end
