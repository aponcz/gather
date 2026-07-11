require 'rails_helper'

RSpec.describe 'Loan create', type: :request do
  let(:admin_email) { "admin-#{SecureRandom.hex(4)}@acme.test" }

  let!(:company) { Company.create!(name: "Acme Lending #{SecureRandom.hex(4)}") }
  let!(:user) do
    User.create!(
      company: company,
      name: 'Admin User',
      email: admin_email,
      password: 'password123',
      role: 'admin'
    )
  end

  let(:token) { JwtService.encode({ sub: user.id, company_id: company.id }, expires_in: 1.hour) }
  let(:headers) { json_headers('Authorization' => "Bearer #{token}") }

  describe 'POST /api/v1/loans' do
    it 'creates an loan using direct recipients without global contacts' do
      first_email = "borrower1-#{SecureRandom.hex(4)}@acme.test"
      second_email = "borrower2-#{SecureRandom.hex(4)}@acme.test"

      post '/api/v1/loans', params: {
        recipients: [
          { name: 'Borrower One', email: first_email, phone: '555-0101' },
          { name: 'Borrower Two', email: second_email }
        ],
        title: 'SBA Loan Package',
        message: 'Please upload the requested documents.',
        loan_amount_in_cents: 25_000_050,
        loan_type: 'SBA 7(a)',
        request_items: [
          { title: 'Tax Returns', kind: 'document', required: true, section_name: 'Financials' }
        ]
      }.to_json, headers: headers

      expect(response).to have_http_status(:created)
      body = json_body

      expect(body['title']).to eq('SBA Loan Package')
      expect(body['loan_amount_in_cents']).to eq(25_000_050)
      expect(body['loan_type']).to eq('SBA 7(a)')
      expect(body.dig('contacts').length).to eq(2)
      expect(body.dig('contacts').map { |recipient| recipient['email'] }.sort).to eq([first_email, second_email].sort)
      expect(body.dig('contacts').all? { |recipient| recipient['contact_id'].nil? }).to eq(true)
      expect(body.dig('request_items').length).to eq(1)

      loan = company.loans.find(body['id'])
      expect(loan.loan_contacts.count).to eq(2)
      expect(loan.loan_contacts.pluck(:contact_id).compact).to be_empty
      expect(loan.request_items.count).to eq(1)
      expect(loan.loan_amount_in_cents).to eq(25_000_050)
      expect(loan.loan_type).to eq('SBA 7(a)')
    end

    it 'returns validation error when no recipients are provided' do
      post '/api/v1/loans', params: {
        title: 'SBA Loan Package',
        request_items: []
      }.to_json, headers: headers

      expect(response).to have_http_status(:unprocessable_entity)
      expect(json_body).to eq({ 'error' => 'recipients_required' })
    end
  end
end
