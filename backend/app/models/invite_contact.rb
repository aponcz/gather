class InviteContact < ApplicationRecord
  belongs_to :invite
  belongs_to :contact

  validates :invite_id, uniqueness: { scope: :contact_id }
end
