class CompanyMembership < ApplicationRecord
  belongs_to :company
  belongs_to :user

  enum role: { owner: "owner", admin: "admin", member: "member" }

  validates :role, presence: true
  validates :user_id, uniqueness: { scope: :company_id }
end
