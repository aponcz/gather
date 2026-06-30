require 'rails_helper'

RSpec.describe 'Devise API Auth', type: :request do
  describe 'POST /api/v1/auth/sign_in' do
    let(:login_email) { "devise-login-#{SecureRandom.hex(4)}@acme.test" }
    let!(:company) { Company.create!(name: "Acme Lending #{SecureRandom.hex(3)}") }
    let!(:other_company) { Company.create!(name: "Beacon Capital #{SecureRandom.hex(3)}") }
    let!(:user) do
      User.create!(
        company: company,
        name: 'Admin User',
        email: login_email,
        password: 'password123',
        role: 'admin'
      )
    end

    before do
      CompanyMembership.create!(company: other_company, user: user, role: 'member')
    end

    it 'signs in successfully and returns token, user, and companies' do
      post '/api/v1/auth/sign_in', params: {
        user: {
          email: login_email,
          password: 'password123',
          company_id: company.id
        }
      }.to_json, headers: json_headers

      expect(response).to have_http_status(:ok)
      body = json_body
      expect(body['token']).to be_present
      expect(body.dig('user', 'email')).to eq(login_email)
      expect(body.dig('company', 'id')).to eq(company.id)
      expect(body['companies'].map { |entry| entry['id'] }).to include(company.id, other_company.id)
    end

    it 'returns unauthorized for invalid credentials' do
      post '/api/v1/auth/sign_in', params: {
        user: {
          email: login_email,
          password: 'wrong-password'
        }
      }.to_json, headers: json_headers

      expect(response).to have_http_status(:unauthorized)
      expect(json_body).to eq({ 'error' => 'invalid_credentials' })
    end

    it 'returns not_found when requested company is not in user memberships' do
      stranger_company = Company.create!(name: "Stranger Company #{SecureRandom.hex(4)}")

      post '/api/v1/auth/sign_in', params: {
        user: {
          email: login_email,
          password: 'password123',
          company_id: stranger_company.id
        }
      }.to_json, headers: json_headers

      expect(response).to have_http_status(:not_found)
      expect(json_body).to eq({ 'error' => 'not_found' })
    end
  end

  describe 'POST /api/v1/auth' do
    let(:registration_email) { "devise-register-#{SecureRandom.hex(4)}@sunrise.test" }
    let(:registration_company_name) { "Sunrise Financial #{SecureRandom.hex(4)}" }
    let(:bad_registration_company_name) { "Bad Registration Co #{SecureRandom.hex(4)}" }

    it 'registers a user into a new company' do
      post '/api/v1/auth', params: {
        user: {
          company_name: registration_company_name,
          name: 'New Admin',
          email: registration_email,
          password: 'password123',
          password_confirmation: 'password123'
        }
      }.to_json, headers: json_headers

      expect(response).to have_http_status(:created)
      body = json_body
      expect(body['token']).to be_present
      expect(body.dig('user', 'email')).to eq(registration_email)
      expect(body.dig('company', 'name')).to eq(registration_company_name)
    end

    it 'returns validation errors for invalid registration data' do
      post '/api/v1/auth', params: {
        user: {
          company_name: bad_registration_company_name,
          name: '',
          email: 'invalid-email',
          password: 'short',
          password_confirmation: 'mismatch'
        }
      }.to_json, headers: json_headers

      expect(response).to have_http_status(:unprocessable_entity)
      body = json_body
      expect(body['error']).to eq('validation_failed')
      expect(body['details']).to be_present
    end
  end

  describe 'POST /api/v1/auth/password' do
    let!(:company) { Company.create!(name: "Acme Lending #{SecureRandom.hex(3)}") }
    let(:recover_email) { "recover-user-#{SecureRandom.hex(4)}@acme.test" }
    let!(:user) do
      User.create!(
        company: company,
        name: 'Recover User',
        email: recover_email,
        password: 'password123',
        role: 'admin'
      )
    end

    it 'returns generic response for forgot-password request' do
      post '/api/v1/auth/password', params: {
        user: { email: user.email }
      }.to_json, headers: json_headers

      expect(response).to have_http_status(:ok)
      expect(json_body).to eq({ 'message' => 'If an account exists with that email, reset instructions have been sent.' })
    end

    it 'resets password with a valid token' do
      token = user.send_reset_password_instructions

      put '/api/v1/auth/password', params: {
        user: {
          reset_password_token: token,
          password: 'newpassword123',
          password_confirmation: 'newpassword123'
        }
      }.to_json, headers: json_headers

      expect(response).to have_http_status(:ok)
      expect(json_body).to eq({ 'message' => 'Password reset successful' })
      expect(user.reload.authenticate('newpassword123')).to be_present
    end

    it 'returns validation_failed for invalid reset token' do
      put '/api/v1/auth/password', params: {
        user: {
          reset_password_token: 'invalid-token',
          password: 'newpassword123',
          password_confirmation: 'newpassword123'
        }
      }.to_json, headers: json_headers

      expect(response).to have_http_status(:unprocessable_entity)
      body = json_body
      expect(body['error']).to eq('validation_failed')
      expect(body['details']).to be_present
    end
  end

  describe 'POST /api/v1/auth/confirmation' do
    let!(:company) { Company.create!(name: "Acme Lending #{SecureRandom.hex(3)}") }
    let(:confirm_email) { "confirm-user-#{SecureRandom.hex(4)}@acme.test" }
    let!(:user) do
      User.create!(
        company: company,
        name: 'Confirm User',
        email: confirm_email,
        password: 'password123',
        role: 'admin'
      )
    end

    it 'returns generic response when requesting confirmation instructions' do
      post '/api/v1/auth/confirmation', params: {
        user: { email: user.email }
      }.to_json, headers: json_headers

      expect(response).to have_http_status(:ok)
      expect(json_body).to eq({ 'message' => 'If your account exists, confirmation instructions have been sent.' })
    end

    it 'returns validation_failed for invalid confirmation token' do
      get '/api/v1/auth/confirmation', params: { confirmation_token: 'invalid-token' }

      expect(response).to have_http_status(:unprocessable_entity)
      body = json_body
      expect(body['error']).to eq('validation_failed')
      expect(body['details']).to be_present
    end
  end
end
