class User < ApplicationRecord
  devise :registerable, :lockable,
         :recoverable, :rememberable, :trackable, :validatable, :confirmable,
         :password_archivable, :password_expirable

  attr_reader :password

  belongs_to :company, optional: true
  has_many :company_memberships, dependent: :destroy
  has_many :companies, through: :company_memberships
  has_many :audit_events, dependent: :nullify

  enum role: { god: "god", admin: "admin", customer: "customer" }

  validates :email, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :name, presence: true

  before_create :skip_confirmation!
  after_save :ensure_primary_company_membership

  def membership_for(company)
    return nil if company.blank?

    company_memberships.find_by(company_id: company.id)
  end

  def role_for(company)
    membership_for(company)&.role
  end

  def admin_for?(company)
    %w[admin owner].include?(role_for(company))
  end

  def password=(new_password)
    @password = new_password
    self.password_digest = BCrypt::Password.create(new_password) if new_password.present?
  end

  def authenticate(unencrypted_password)
    return false if password_digest.blank?

    BCrypt::Password.new(password_digest).is_password?(unencrypted_password) ? self : false
  end

  def password_digest
    self[:password_digest]
  end

  def password_digest=(value)
    self[:password_digest] = value
  end

  private

  def ensure_primary_company_membership
    return if company_id.blank?

    membership = company_memberships.find_or_initialize_by(company_id: company_id)
    if membership.new_record?
      membership.role = role == "customer" ? "member" : "admin"
    elsif membership.role.blank?
      membership.role = role == "customer" ? "member" : "admin"
    end
    membership.save! if membership.new_record?
  end
end
