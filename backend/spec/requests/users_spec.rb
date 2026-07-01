require 'rails_helper'

RSpec.describe 'Users', type: :request do
  let!(:company) { Company.create!(name: "Test Company #{SecureRandom.hex(3)}", subdomain: "test-#{SecureRandom.hex(2)}") }

  let!(:god_user) do
    User.create!(
      company: company,
      name: 'God User',
      email: "god-#{SecureRandom.hex(4)}@example.test",
      password: 'password123',
      role: 'god'
    )
  end

  let!(:admin_user) do
    User.create!(
      company: company,
      name: 'Admin User',
      email: "admin-#{SecureRandom.hex(4)}@example.test",
      password: 'password123',
      role: 'admin'
    )
  end

  let!(:customer_user) do
    User.create!(
      company: company,
      name: 'Customer User',
      email: "customer-#{SecureRandom.hex(4)}@example.test",
      password: 'password123',
      role: 'customer'
    )
  end

  let!(:target_user) do
    User.create!(
      company: company,
      name: 'Target User',
      email: "target-#{SecureRandom.hex(4)}@example.test",
      password: 'password123',
      role: 'customer'
    )
  end

  let(:god_headers) do
    token = JwtService.encode({ sub: god_user.id, company_id: company.id }, expires_in: 1.hour)
    json_headers('Authorization' => "Bearer #{token}")
  end

  let(:admin_headers) do
    token = JwtService.encode({ sub: admin_user.id, company_id: company.id }, expires_in: 1.hour)
    json_headers('Authorization' => "Bearer #{token}")
  end

  let(:customer_headers) do
    token = JwtService.encode({ sub: customer_user.id, company_id: company.id }, expires_in: 1.hour)
    json_headers('Authorization' => "Bearer #{token}")
  end

  describe 'GET /api/v1/users' do
    context 'when user is authenticated as god' do
      it 'returns all users' do
        get '/api/v1/users', headers: god_headers
        expect(response).to have_http_status(:ok)
        expect(json_body.length).to be >= 4
        user_ids = json_body.map { |u| u['id'] }
        expect(user_ids).to include(god_user.id, admin_user.id, customer_user.id, target_user.id)
      end
    end

    context 'when user is authenticated as admin' do
      it 'returns all users' do
        get '/api/v1/users', headers: admin_headers
        expect(response).to have_http_status(:ok)
        expect(json_body.length).to be >= 4
        user_ids = json_body.map { |u| u['id'] }
        expect(user_ids).to include(god_user.id, admin_user.id, customer_user.id, target_user.id)
      end
    end

    context 'when user is authenticated as customer' do
      it 'returns forbidden' do
        get '/api/v1/users', headers: customer_headers
        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'when user is not authenticated' do
      it 'returns unauthorized' do
        get '/api/v1/users', headers: json_headers
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'PATCH /api/v1/users/:id' do
    context 'when user is authenticated as god' do
      it 'updates user role' do
        patch "/api/v1/users/#{target_user.id}",
              params: { role: 'admin' }.to_json,
              headers: god_headers
        expect(response).to have_http_status(:ok)
        expect(json_body['role']).to eq('admin')
        expect(target_user.reload.role).to eq('admin')
      end
    end

    context 'when user is authenticated as admin' do
      it 'updates user role' do
        patch "/api/v1/users/#{target_user.id}",
              params: { role: 'god' }.to_json,
              headers: admin_headers
        expect(response).to have_http_status(:ok)
        expect(json_body['role']).to eq('god')
        expect(target_user.reload.role).to eq('god')
      end
    end

    context 'when user is authenticated as customer' do
      it 'returns forbidden' do
        patch "/api/v1/users/#{target_user.id}",
              params: { role: 'admin' }.to_json,
              headers: customer_headers
        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'when user is not authenticated' do
      it 'returns unauthorized' do
        patch "/api/v1/users/#{target_user.id}",
              params: { role: 'admin' }.to_json,
              headers: json_headers
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
