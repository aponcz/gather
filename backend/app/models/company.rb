class Company < ApplicationRecord
	has_many :company_memberships, dependent: :destroy
	has_many :users, through: :company_memberships
	has_many :contacts, dependent: :destroy, inverse_of: :company
	has_many :invites, dependent: :destroy, inverse_of: :company
	has_many :request_items, through: :invites
	has_many :uploaded_files, through: :request_items

	enum status: {
		trial: 0,
		active: 1,
		delinquent: 2,
		suspended: 3
	}

	validates :name, presence: true
	validates :protext_id, uniqueness: true, allow_nil: true
	validates :subdomain,
						uniqueness: true,
						format: { with: /\A[a-z0-9]+(?:-[a-z0-9]+)*\z/, message: "must use lowercase letters, numbers, or hyphens" },
						allow_blank: true
	validates :custom_domain,
						uniqueness: true,
						format: { with: /\A([a-z0-9]+(-[a-z0-9]+)*\.)+[a-z0-9]{2,}\z/, message: "must be a valid domain name" },
						allow_blank: true
	validates :website,
						format: { with: URI::DEFAULT_PARSER.make_regexp(%w[http https]), message: "must be a valid URL" },
						allow_blank: true
	validates :state, length: { is: 2, message: "must be 2 characters" }, allow_blank: true
	validates :zip_code, format: { with: /\A\d{5}(?:-\d{4})?\z/, message: "must be a valid ZIP code" }, allow_blank: true
	validates :phone_number, length: { maximum: 25 }, allow_blank: true

	class << self
		def find_by_host(host)
			return nil if host.blank?

			# Split host to remove port
			hostname = host.split(':').first.downcase

			# Try custom domain first
			company = find_by(custom_domain: hostname)
			return company if company.present?

			# Extract subdomain and try subdomain-based lookup
			# For localhost or IP addresses, try to extract subdomain
			if hostname.include?('.')
				parts = hostname.split('.')
				subdomain = parts.first
				company = find_by(subdomain: subdomain) if subdomain.present? && subdomain != 'localhost'
				return company if company.present?
			end

			nil
		end
	end
end
