require 'rails_helper'

RSpec.describe 'Companies', type: :request do
  let!(:company_a) { Company.create!(name: "Alpha #{SecureRandom.hex(3)}", subdomain: "alpha-#{SecureRandom.hex(2)}") }
  let!(:company_b) { Company.create!(name: "Beta #{SecureRandom.hex(3)}", subdomain: "beta-#{SecureRandom.hex(2)}") }

  let!(:admin_user) do
    User.create!(
      company: company_a,
      name: 'Admin User',
      email: "admin-#{SecureRandom.hex(4)}@example.test",
      password: 'password123',
      role: 'admin'
    )
  end

  let!(:god_user) do
    User.create!(
      company: company_a,
      name: 'God User',
      email: "god-#{SecureRandom.hex(4)}@example.test",
      password: 'password123',
      role: 'god'
    )
  end

  let!(:customer_user) do
    User.create!(
      company: company_a,
      name: 'Customer User',
      email: "customer-#{SecureRandom.hex(4)}@example.test",
      password: 'password123',
      role: 'customer'
    )
  end

  let(:admin_headers) do
    token = JwtService.encode({ sub: admin_user.id, company_id: company_a.id }, expires_in: 1.hour)
    json_headers('Authorization' => "Bearer #{token}")
  end

  let(:god_headers) do
    token = JwtService.encode({ sub: god_user.id, company_id: company_a.id }, expires_in: 1.hour)
    json_headers('Authorization' => "Bearer #{token}")
  end

  let(:customer_headers) do
    token = JwtService.encode({ sub: customer_user.id, company_id: company_a.id }, expires_in: 1.hour)
    json_headers('Authorization' => "Bearer #{token}")
  end

  describe 'GET /api/v1/companies' do
    it 'returns all companies for admin users' do
      get '/api/v1/companies', headers: admin_headers

      expect(response).to have_http_status(:ok)
      body = json_body
      ids = body.map { |company| company['id'] }
      expect(ids).to include(company_a.id, company_b.id)
    end

    it 'returns all companies for god users' do
      get '/api/v1/companies', headers: god_headers

      expect(response).to have_http_status(:ok)
      body = json_body
      ids = body.map { |company| company['id'] }
      expect(ids).to include(company_a.id, company_b.id)
    end

    it 'returns forbidden for customer users' do
      get '/api/v1/companies', headers: customer_headers

      expect(response).to have_http_status(:forbidden)
      expect(json_body['error']).to eq('forbidden')
    end

    it 'deduplicates companies with same name and domain fields' do
      duplicate_name = "Duplicate Co #{SecureRandom.hex(3)}"
      Company.create!(name: duplicate_name)
      Company.create!(name: duplicate_name)

      get '/api/v1/companies', headers: admin_headers

      expect(response).to have_http_status(:ok)
      body = json_body
      duplicate_entries = body.select { |company| company['name'] == duplicate_name }
      expect(duplicate_entries.size).to eq(1)
    end
  end
end
