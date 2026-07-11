class UploadedFile < ApplicationRecord
  belongs_to :request_item
  belongs_to :uploaded_by_contact, class_name: "Contact", optional: true
  belongs_to :reviewed_by, class_name: "User", optional: true

  enum status: { uploaded: "uploaded", approved: "approved", rejected: "rejected", quarantined: "quarantined" }

  validates :storage_key, :filename, :content_type, presence: true

  after_create :mark_request_item_submitted

  private

  def mark_request_item_submitted
    request_item.submitted! if request_item.pending? || request_item.rejected?
    request_item.loan.refresh_status!
  end
end
