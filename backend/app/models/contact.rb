class Contact < ApplicationRecord
  belongs_to :organization
  has_many :invites, dependent: :destroy
  has_many :invite_contacts, dependent: :destroy
  has_many :invites_as_participant, through: :invite_contacts, source: :invite

  validates :email, presence: true, uniqueness: { scope: :organization_id }, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :name, presence: true
end
