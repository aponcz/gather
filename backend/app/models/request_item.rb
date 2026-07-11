class RequestItem < ApplicationRecord
  belongs_to :loan
  has_one :company, through: :loan
  has_many :uploaded_files, dependent: :destroy

  enum kind: { document: "document", form: "form", signature: "signature" }
  enum status: { pending: "pending", submitted: "submitted", approved: "approved", rejected: "rejected" }

  validates :title, presence: true
  validates :kind, presence: true
end
