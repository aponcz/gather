class Loan < ApplicationRecord
  belongs_to :company, inverse_of: :loans
  belongs_to :contact, optional: true
  belongs_to :created_by, class_name: "User"
  has_many :request_items, dependent: :destroy
  has_many :uploaded_files, through: :request_items
  has_many :audit_events, dependent: :destroy
  has_many :loan_contacts, dependent: :destroy
  has_many :contacts, through: :loan_contacts

  enum status: {
    draft: "draft",
    sent: "sent",
    viewed: "viewed",
    partially_submitted: "partially_submitted",
    submitted: "submitted",
    completed: "completed",
    cancelled: "cancelled"
  }

  validates :title, presence: true

  before_create :set_public_token

  def refresh_status!
    if request_items.any? && request_items.all?(&:approved?)
      completed!
    elsif request_items.any? && request_items.all? { |i| i.submitted? || i.approved? }
      submitted!
    elsif request_items.any? { |i| i.submitted? || i.approved? || i.rejected? }
      partially_submitted!
    end
  end

  private

  def set_public_token
    self.public_token ||= SecureRandom.urlsafe_base64(32)
  end

  public

  def recipient_contacts
    recipients = loan_contacts.includes(:contact).map(&:recipient_payload)
    if recipients.empty? && contact.present?
      recipients = [{
        "id" => contact.id,
        "name" => contact.name,
        "email" => contact.email,
        "phone" => contact.phone
      }]
    end
    recipients
  end

  def primary_recipient
    recipient_contacts.first
  end

  def primary_recipient_email
    primary_recipient && primary_recipient["email"]
  end
end
