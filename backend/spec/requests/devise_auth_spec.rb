require 'rails_helper'

RSpec.describe 'Devise API Auth', type: :request do
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
