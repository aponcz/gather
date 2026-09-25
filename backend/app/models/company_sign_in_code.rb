require "digest"

class CompanySignInCode < ApplicationRecord
  belongs_to :user
  belongs_to :company

  def self.issue(user:, company:)
    where("expires_at <= ?", Time.current).delete_all
    code = SecureRandom.urlsafe_base64(32)
    create!(user: user, company: company, digest: Digest::SHA256.hexdigest(code), expires_at: 1.minute.from_now)
    code
  end

  def self.consume(code)
    transaction do
      record = lock.find_by(digest: Digest::SHA256.hexdigest(code))
      return nil unless record

      record.destroy!
      record if record.expires_at > Time.current
    end
  end
end
