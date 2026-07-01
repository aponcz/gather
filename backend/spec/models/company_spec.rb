require 'rails_helper'

RSpec.describe Company, type: :model do
  describe '.find_by_host' do
    let(:subdomain) { "acme#{SecureRandom.hex(3)}" }
    let(:company) { Company.create!(name: "Host Lookup #{SecureRandom.hex(4)}", subdomain: subdomain, custom_domain: "docs.acme#{SecureRandom.hex(2)}.com") }

    it 'finds company by custom domain' do
      result = Company.find_by_host(company.custom_domain)
      expect(result).to eq(company)
    end

    it 'finds company by custom domain with port' do
      result = Company.find_by_host("#{company.custom_domain}:3000")
      expect(result).to eq(company)
    end

    it 'finds company by subdomain' do
      result = Company.find_by_host("#{company.subdomain}.gather.local")
      expect(result).to eq(company)
    end

    it 'returns nil for unknown host' do
      result = Company.find_by_host("unknown#{SecureRandom.hex(4)}.com")
      expect(result).to be_nil
    end

    it 'returns nil for blank host' do
      result = Company.find_by_host("")
      expect(result).to be_nil
    end

    it 'prefers custom domain over subdomain' do
      result = Company.find_by_host(company.custom_domain)
      expect(result).to eq(company)
    end
  end

  describe 'validations' do
    it 'validates custom_domain format' do
      company = Company.new(name: 'Test', custom_domain: 'invalid domain')
      expect(company).to be_invalid
      expect(company.errors[:custom_domain]).to include('must be a valid domain name')
    end

    it 'validates custom_domain uniqueness' do
      Company.create!(name: 'Company 1', custom_domain: "docs#{SecureRandom.hex(4)}.com")
      company2 = Company.new(name: 'Company 2', custom_domain: "docs#{SecureRandom.hex(4)}.com")
      # This should be valid since the domain is different
      expect(company2).to be_valid
    end

    it 'allows blank custom_domain' do
      company = Company.new(name: 'Test', custom_domain: '')
      expect(company).to be_valid
    end
  end
end
