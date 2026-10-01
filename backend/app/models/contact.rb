class Contact < ApplicationRecord
  scope :active, -> { where(deleted_at: nil) }

  belongs_to :company, inverse_of: :contacts
  has_many :loans, dependent: :destroy
  has_many :loan_contacts, dependent: :destroy
  has_many :loans_as_participant, through: :loan_contacts, source: :loan

  validates :email, presence: true, uniqueness: { scope: :company_id, conditions: -> { where(deleted_at: nil) } }, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :name, presence: true

  def soft_delete!
    update!(deleted_at: Time.current)
  end
end
