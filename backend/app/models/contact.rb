class Contact < ApplicationRecord
  belongs_to :organization
  has_many :invites, dependent: :destroy

  validates :email, presence: true, uniqueness: { scope: :organization_id }, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :name, presence: true
end
