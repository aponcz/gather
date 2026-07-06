class InviteContact < ApplicationRecord
  belongs_to :invite
  belongs_to :contact, optional: true

  validates :contact_id, uniqueness: { scope: :invite_id }, allow_nil: true
  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :name, presence: true
  validates :email, uniqueness: { scope: :invite_id, case_sensitive: false }

  before_validation :apply_contact_defaults

  def recipient_payload
    {
      "id" => id,
      "contact_id" => contact_id,
      "name" => name,
      "email" => email,
      "phone" => phone
    }
  end

  private

  def apply_contact_defaults
    return unless contact.present?

    self.name = contact.name if name.blank?
    self.email = contact.email if email.blank?
    self.phone = contact.phone if phone.blank?
  end
end
