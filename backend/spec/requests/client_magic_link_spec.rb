require 'rails_helper'

RSpec.describe 'Client magic link', type: :request do
  let!(:company) { Company.create!(name: "Magic Link Co #{SecureRandom.hex(4)}") }
  let!(:creator) do
    User.create!(
      company: company,
      name: 'Admin User',
      email: "admin-#{SecureRandom.hex(4)}@example.test",
      password: 'password123',
      role: 'admin'
    )
  end
  let!(:loan) { Loan.create!(company: company, created_by: creator, title: 'Direct recipient loan', status: 'sent') }
  let!(:loan_contact) do
    LoanContact.create!(loan: loan, name: 'Direct Recipient', email: "direct-#{SecureRandom.hex(4)}@example.test")
  end
  let(:magic_token) do
    JwtService.encode(
      { loan_contact_id: loan_contact.id, company_id: company.id, loan_id: loan.id, type: 'client_magic' },
      expires_in: 1.hour
    )
  end

  it 'exchanges the emailed token and opens the associated loan' do
    post '/api/v1/client/sessions', params: { magic_token: magic_token }.to_json, headers: json_headers

    expect(response).to have_http_status(:ok)
    session_token = json_body.fetch('token')
    expect(JwtService.decode(session_token)).to include(
      'type' => 'client',
      'loan_contact_id' => loan_contact.id,
      'company_id' => company.id
    )

    get "/api/v1/client/loans/#{loan.public_token}", headers: { 'Authorization' => "Bearer #{session_token}" }

    expect(response).to have_http_status(:ok)
    expect(json_body['id']).to eq(loan.id)
  end

  it 'does not grant access to another loan' do
    other_loan = Loan.create!(company: company, created_by: creator, title: 'Another loan', status: 'sent')

    post '/api/v1/client/sessions', params: { magic_token: magic_token }.to_json, headers: json_headers
    session_token = json_body.fetch('token')
    get "/api/v1/client/loans/#{other_loan.public_token}", headers: { 'Authorization' => "Bearer #{session_token}" }

    expect(response).to have_http_status(:not_found)
  end
end
