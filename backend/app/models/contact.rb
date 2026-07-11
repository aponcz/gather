class Contact < ApplicationRecord
  belongs_to :company, inverse_of: :contacts
  has_many :loans, dependent: :destroy
  has_many :loan_contacts, dependent: :destroy
  has_many :loans_as_participant, through: :loan_contacts, source: :loan

  validates :email, presence: true, uniqueness: { scope: :company_id }, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :name, presence: true
end
