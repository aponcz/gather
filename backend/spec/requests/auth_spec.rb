require 'rails_helper'

RSpec.describe 'Auth', type: :request do
  describe 'POST /api/v1/auth/register' do
    it 'registers a company admin and returns token and payload' do
      company_name = "Acme Lending #{SecureRandom.hex(4)}"
      email = "register-admin-#{SecureRandom.hex(4)}@acme.test"

      post '/api/v1/auth/register', params: {
        company_name: company_name,
        name: 'Admin User',
        email: email,
        password: 'password123'
      }.to_json, headers: json_headers

      expect(response).to have_http_status(:created)

      body = json_body
      expect(body['token']).to be_present
      expect(body.dig('user', 'email')).to eq(email)
      expect(body.dig('user', 'role')).to eq('admin')
      expect(body.dig('company', 'name')).to eq(company_name)

      company = Company.find(body.dig('company', 'id'))
      user = User.find_by!(email: email)
      expect(user.company_id).to eq(company.id)
      expect(user.authenticate('password123')).to be_present
    end
  end

  describe 'POST /api/v1/auth/login' do
    let(:login_email) { "login-admin-#{SecureRandom.hex(4)}@acme.test" }
    let!(:company) { Company.create!(name: "Acme Lending #{SecureRandom.hex(4)}") }
    let!(:user) do
      User.create!(
        company: company,
        name: 'Admin User',
        email: login_email,
        password: 'password123',
        role: 'admin'
      )
    end

    it 'returns a token and user payload for valid credentials' do
      post '/api/v1/auth/login', params: {
        email: login_email,
        password: 'password123'
      }.to_json, headers: json_headers

      expect(response).to have_http_status(:ok)

      body = json_body
      expect(body['token']).to be_present
      expect(body.dig('user', 'email')).to eq(login_email)
      expect(body.dig('company', 'id')).to eq(company.id)

      expect(user.reload.last_login_at).to be_present
    end

    it 'returns unauthorized for invalid password' do
      post '/api/v1/auth/login', params: {
        email: login_email,
        password: 'wrong-password'
      }.to_json, headers: json_headers

      expect(response).to have_http_status(:unauthorized)
      expect(json_body).to eq({ 'error' => 'invalid_credentials' })
    end
  end

  describe 'GET /api/v1/me' do
    let(:me_email) { "me-admin-#{SecureRandom.hex(4)}@acme.test" }
    let!(:company) { Company.create!(name: "Acme Lending #{SecureRandom.hex(4)}") }
    let!(:user) do
      User.create!(
        company: company,
        name: 'Admin User',
        email: me_email,
        password: 'password123',
        role: 'admin'
      )
    end

    let(:token) { JwtService.encode({ sub: user.id, company_id: company.id, type: 'user' }, expires_in: 1.hour) }

    it 'returns current user and company for a valid token' do
      get '/api/v1/me', headers: { 'Authorization' => "Bearer #{token}" }

      expect(response).to have_http_status(:ok)

      body = json_body
      expect(body.dig('user', 'id')).to eq(user.id)
      expect(body.dig('user', 'email')).to eq(me_email)
      expect(body.dig('company', 'id')).to eq(company.id)
    end

    it 'returns unauthorized when token is missing' do
      get '/api/v1/me'

      expect(response).to have_http_status(:unauthorized)
      expect(json_body).to eq({ 'error' => 'missing_token' })
    end
  end

  describe 'POST /api/v1/auth/switch-company' do
    let(:switch_email) { "switch-user-#{SecureRandom.hex(4)}@acme.test" }
    let!(:company) { Company.create!(name: "Acme Lending #{SecureRandom.hex(4)}") }
    let!(:other_company) { Company.create!(name: "Beacon Capital #{SecureRandom.hex(4)}") }
    let!(:third_company) { Company.create!(name: "Delta Credit #{SecureRandom.hex(4)}") }
    let!(:user) do
      User.create!(
        company: company,
        name: 'Switch User',
        email: switch_email,
        password: 'password123',
        role: 'admin'
      )
    end
    let!(:secondary_membership) { CompanyMembership.create!(company: other_company, user: user, role: 'member') }

    let(:token) { JwtService.encode({ sub: user.id, company_id: company.id, type: 'user' }, expires_in: 1.hour) }
    let(:headers) { json_headers('Authorization' => "Bearer #{token}") }

    it 'switches active company and returns a token scoped to the selected company' do
      post '/api/v1/auth/switch-company', params: { company_id: other_company.id }.to_json, headers: headers

      expect(response).to have_http_status(:ok)
      body = json_body
      expect(body.dig('company', 'id')).to eq(other_company.id)
      expect(body.dig('user', 'company_id')).to eq(other_company.id)
      decoded = JwtService.decode(body.fetch('token'))
      expect(decoded['company_id']).to eq(other_company.id)
    end

    it 'returns forbidden when switching to a company the user is not a member of' do
      post '/api/v1/auth/switch-company', params: { company_id: third_company.id }.to_json, headers: headers

      expect(response).to have_http_status(:forbidden)
      expect(json_body).to eq({ 'error' => 'forbidden' })
    end
  end

  describe 'POST /api/v1/auth/forgot-password' do
    let(:forgot_email) { "forgot-user-#{SecureRandom.hex(4)}@acme.test" }
    let(:unknown_email) { "unknown-#{SecureRandom.hex(4)}@acme.test" }
    let!(:company) { Company.create!(name: "Acme Lending #{SecureRandom.hex(4)}") }
    let!(:user) do
      User.create!(
        company: company,
        name: 'Reset User',
        email: forgot_email,
        password: 'password123',
        role: 'admin'
      )
    end

    it 'returns generic success and stores a reset token for existing user' do
      allow(SecureRandom).to receive(:urlsafe_base64).and_return('fixed-reset-token')
      parameterized_mailer = double('ParameterizedMailer')
      message_delivery = instance_double(ActionMailer::MessageDelivery, deliver_later: true)
      allow(parameterized_mailer).to receive(:password_reset_email).and_return(message_delivery)
      allow(CompanyMailer).to receive(:with).with(user: user, company: company, token: 'fixed-reset-token').and_return(parameterized_mailer)

      post '/api/v1/auth/forgot-password', params: { email: user.email }.to_json, headers: json_headers

      expect(response).to have_http_status(:ok)
      expect(json_body).to eq({ 'message' => 'If an account exists with that email, reset instructions have been sent.' })
      expect(Rails.cache.read('password-reset:fixed-reset-token')).to eq(user.id)
      expect(CompanyMailer).to have_received(:with).with(user: user, company: company, token: 'fixed-reset-token')
      expect(parameterized_mailer).to have_received(:password_reset_email)
      expect(message_delivery).to have_received(:deliver_later)
    end

    it 'returns the same generic success response for unknown email' do
      post '/api/v1/auth/forgot-password', params: { email: unknown_email }.to_json, headers: json_headers

      expect(response).to have_http_status(:ok)
      expect(json_body).to eq({ 'message' => 'If an account exists with that email, reset instructions have been sent.' })
    end
  end

  describe 'POST /api/v1/auth/reset-password' do
    let(:reset_email) { "reset-user-#{SecureRandom.hex(4)}@acme.test" }
    let!(:company) { Company.create!(name: "Acme Lending #{SecureRandom.hex(4)}") }
    let!(:user) do
      User.create!(
        company: company,
        name: 'Reset User',
        email: reset_email,
        password: 'password123',
        role: 'admin'
      )
    end

    let(:headers) { json_headers }

    before do
      Rails.cache.write('password-reset:valid-token', user.id, expires_in: 2.hours)
    end

    it 'resets password for a valid token and clears token cache' do
      post '/api/v1/auth/reset-password', params: { token: 'valid-token', password: 'newpassword123' }.to_json, headers: headers

      expect(response).to have_http_status(:ok)
      expect(json_body).to eq({ 'message' => 'Password reset successful' })
      expect(user.reload.authenticate('newpassword123')).to be_present
      expect(user.authenticate('password123')).to be_falsey
      expect(Rails.cache.read('password-reset:valid-token')).to be_nil
    end

    it 'returns error when token is invalid or expired' do
      post '/api/v1/auth/reset-password', params: { token: 'missing-token', password: 'newpassword123' }.to_json, headers: headers

      expect(response).to have_http_status(:unprocessable_entity)
      expect(json_body).to eq({ 'error' => 'Invalid or expired reset token' })
    end

    it 'returns error when password is too short' do
      post '/api/v1/auth/reset-password', params: { token: 'valid-token', password: 'short' }.to_json, headers: headers

      expect(response).to have_http_status(:unprocessable_entity)
      expect(json_body).to eq({ 'error' => 'Password must be at least 8 characters' })
    end
  end
end
