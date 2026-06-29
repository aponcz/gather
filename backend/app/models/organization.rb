class Organization < ApplicationRecord
  has_many :users, dependent: :destroy
  has_many :contacts, dependent: :destroy
  has_many :invites, dependent: :destroy
  has_many :request_items, through: :invites
  has_many :uploaded_files, through: :request_items

  validates :name, presence: true
end
