require 'rails_helper'

RSpec.describe 'Company members', type: :request do
  let(:admin_email) { "admin-#{SecureRandom.hex(4)}@acme.test" }
  let(:owner_email) { "owner-#{SecureRandom.hex(4)}@acme.test" }
  let(:member_email) { "member-#{SecureRandom.hex(4)}@acme.test" }
  let(:new_member_email) { "newmember-#{SecureRandom.hex(4)}@acme.test" }
  let(:blocked_email) { "blocked-#{SecureRandom.hex(4)}@acme.test" }
  let(:bad_role_email) { "badrole-#{SecureRandom.hex(4)}@acme.test" }

  let!(:company) { Company.create!(name: "Acme Lending #{SecureRandom.hex(4)}") }
  let!(:admin_user) do
    User.create!(
      company: company,
      name: 'Admin User',
      email: admin_email,
      password: 'password123',
      role: 'admin'
    )
  end

  let!(:owner_user) do
    User.create!(
      company: company,
      name: 'Owner User',
      email: owner_email,
      password: 'password123',
      role: 'god'
    )
  end

  let!(:member_user) do
    User.create!(
      company: company,
      name: 'Member User',
      email: member_email,
      password: 'password123',
      role: 'customer'
    )
  end

  let(:admin_token) { JwtService.encode({ sub: admin_user.id, company_id: company.id }, expires_in: 1.hour) }
  let(:member_token) { JwtService.encode({ sub: member_user.id, company_id: company.id }, expires_in: 1.hour) }
  let(:admin_headers) { json_headers('Authorization' => "Bearer #{admin_token}") }
  let(:member_headers) { json_headers('Authorization' => "Bearer #{member_token}") }

  describe 'POST /api/v1/company_members' do
    it 'creates a company member and queues invite email' do
      allow(SendMemberInviteJob).to receive(:perform_later)

      post '/api/v1/company_members', params: {
        name: 'New Member',
        email: new_member_email,
        role: 'admin'
      }.to_json, headers: admin_headers

      expect(response).to have_http_status(:created)
      body = json_body
      expect(body['email']).to eq(new_member_email)
      expect(body['role']).to eq('admin')
      expect(body['invitation_status']).to eq('pending')

      created_user = company.users.find_by!(email: new_member_email)
      expect(created_user.role).to eq('customer')
      expect(SendMemberInviteJob).to have_received(:perform_later).with(created_user.id, company.id, kind_of(String)).once
    end

    it 'returns forbidden for non-admin users' do
      post '/api/v1/company_members', params: {
        name: 'Blocked User',
        email: blocked_email
      }.to_json, headers: member_headers

      expect(response).to have_http_status(:forbidden)
      body = json_body
      expect(body['error']).to eq('forbidden')
    end

    it 'returns validation error for invalid role value' do
      post '/api/v1/company_members', params: {
        name: 'Bad Role',
        email: bad_role_email,
        role: 'reviewer'
      }.to_json, headers: admin_headers

      expect(response).to have_http_status(:unprocessable_entity)
      body = json_body
      expect(body['error']).to eq('validation_failed')
      expect(body['details'].join(' ')).to include('Role')
    end
  end

  describe 'GET /api/v1/company_members' do
    it 'returns invitation status for each member' do
      member_user.update!(last_login_at: Time.current)

      get '/api/v1/company_members', headers: admin_headers

      expect(response).to have_http_status(:ok)
      body = json_body
      listed_member = body.find { |member| member['id'] == member_user.id }
      expect(listed_member['invitation_status']).to eq('accepted')
      listed_admin = body.find { |member| member['id'] == admin_user.id }
      expect(listed_admin['invitation_status']).to eq('pending')
    end
  end

  describe 'PATCH /api/v1/company_members/:id' do
    it 'updates a member role' do
      patch "/api/v1/company_members/#{member_user.id}", params: {
        role: 'admin'
      }.to_json, headers: admin_headers

      expect(response).to have_http_status(:ok)
      body = json_body
      expect(body['role']).to eq('admin')
      expect(member_user.reload.role).to eq('customer')
    end

    it 'allows owner to update a member role' do
      owner_token = JwtService.encode({ sub: owner_user.id, company_id: company.id }, expires_in: 1.hour)
      owner_headers = json_headers('Authorization' => "Bearer #{owner_token}")

      patch "/api/v1/company_members/#{member_user.id}", params: {
        role: 'member'
      }.to_json, headers: owner_headers

      expect(response).to have_http_status(:ok)
      expect(member_user.reload.role).to eq('customer')
    end

    it 'returns forbidden for non-admin users' do
      patch "/api/v1/company_members/#{admin_user.id}", params: {
        role: 'member'
      }.to_json, headers: member_headers

      expect(response).to have_http_status(:forbidden)
      body = json_body
      expect(body['error']).to eq('forbidden')
    end

    it 'returns validation error for invalid role value' do
      patch "/api/v1/company_members/#{member_user.id}", params: {
        role: 'reviewer'
      }.to_json, headers: admin_headers

      expect(response).to have_http_status(:unprocessable_entity)
      body = json_body
      expect(body['error']).to eq('validation_failed')
    end
  end
end
