require 'rails_helper'

RSpec.describe 'Loan import loans', type: :request do
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

  let(:token) { JwtService.encode({ sub: user.id, company_id: company.id, type: 'user' }, expires_in: 1.hour) }
  let(:headers) { json_headers('Authorization' => "Bearer #{token}") }

  around do |example|
    original_client_id = ENV['GOPROTEXT_OAUTH_CLIENT_ID']
    original_client_secret = ENV['GOPROTEXT_OAUTH_CLIENT_SECRET']
    original_token_url = ENV['GOPROTEXT_OAUTH_TOKEN_URL']
    original_loans_url = ENV['GOPROTEXT_LOANS_URL']

    ENV['GOPROTEXT_OAUTH_CLIENT_ID'] = 'goprotext-client-id'
    ENV['GOPROTEXT_OAUTH_CLIENT_SECRET'] = 'goprotext-client-secret'
    ENV['GOPROTEXT_OAUTH_TOKEN_URL'] = 'https://id.stage.goprotext.com/oauth/token'
    ENV['GOPROTEXT_LOANS_URL'] = 'https://id.stage.goprotext.com/api/v2/loans'

    example.run
  ensure
    ENV['GOPROTEXT_OAUTH_CLIENT_ID'] = original_client_id
    ENV['GOPROTEXT_OAUTH_CLIENT_SECRET'] = original_client_secret
    ENV['GOPROTEXT_OAUTH_TOKEN_URL'] = original_token_url
    ENV['GOPROTEXT_LOANS_URL'] = original_loans_url
  end

  def build_http_success(payload)
    response = Net::HTTPOK.new('1.1', '200', 'OK')
    response.instance_variable_set(:@read, true)
    response.instance_variable_set(:@body, payload.to_json)
    response
  end

  describe 'POST /api/v1/loans/import_loans' do
    it 'imports loans from protext and creates loans' do
      allow_any_instance_of(ProtextLoansImportService)
        .to receive(:perform_http_request)
        .and_return(
          build_http_success('access_token' => 'oauth-access-token'),
          build_http_success([
            {
              'id' => 'loan-1',
              'borrower_name' => 'Jane Borrower',
              'loan_number' => '1001',
              'loan_amount' => '$345,678.90',
              'loan_type' => 'Bridge',
              'borrower' => {
                'name' => 'Jane Borrower',
                'email' => 'jane.borrower@example.test',
                'phone' => '555-0101'
              }
            },
            {
              'id' => 'loan-2',
              'borrower_name' => 'John Borrower',
              'borrower' => {
                'first_name' => 'John',
                'last_name' => 'Borrower',
                'email' => 'john.borrower@example.test'
              }
            }
          ])
        )

      post '/api/v1/loans/import_loans', headers: headers

      expect(response).to have_http_status(:created)
      body = json_body
      expect(body['fetched_count']).to eq(2)
      expect(body['created_count']).to eq(2)
      expect(body['skipped_count']).to eq(0)

      loans = company.loans.order(:created_at)
      expect(loans.count).to eq(2)
      expect(loans.first.title).to eq('Jane Borrower')
      expect(loans.first.message).to eq('OAuth imported from ProText loan sync.')
      expect(loans.first.protext_id).to be_nil
      expect(loans.first.loan_amount_in_cents).to eq(34_567_890)
      expect(loans.first.loan_type).to eq('Bridge')

      recipients = loans.first.loan_contacts
      expect(recipients.count).to eq(0)
    end

    it 'skips duplicate loans already imported' do
      existing_loan = company.loans.create!(
        title: 'Existing Loan Loan',
        message: "Imported from ProText loan sync.\n[ProText Loan ID: loan-1]",
        created_by: user,
        status: 'draft',
        protext_id: 'loan-1'
      )
      existing_loan.loan_contacts.create!(name: 'Existing Borrower', email: 'existing.borrower@example.test')

      allow_any_instance_of(ProtextLoansImportService)
        .to receive(:perform_http_request)
        .and_return(
          build_http_success('access_token' => 'oauth-access-token'),
          build_http_success([
            {
              'id' => 'loan-1',
              'borrower_name' => 'Duplicate Borrower',
              'borrower' => {
                'name' => 'Duplicate Borrower',
                'email' => 'duplicate.borrower@example.test'
              }
            },
            {
              'id' => 'loan-3',
              'borrower_name' => 'Fresh Borrower',
              'borrower' => {
                'name' => 'Fresh Borrower',
                'email' => 'fresh.borrower@example.test'
              }
            }
          ])
        )

      post '/api/v1/loans/import_loans', headers: headers

      expect(response).to have_http_status(:created)
      body = json_body
      expect(body['fetched_count']).to eq(2)
      expect(body['created_count']).to eq(2)
      expect(body['skipped_count']).to eq(0)
      expect(company.loans.count).to eq(3)
    end

    it 'returns bad gateway when protext call fails' do
      failed_response = Net::HTTPUnauthorized.new('1.1', '401', 'Unauthorized')
      failed_response.instance_variable_set(:@read, true)
      failed_response.instance_variable_set(:@body, { error: 'invalid_client' }.to_json)

      allow_any_instance_of(ProtextLoansImportService)
        .to receive(:perform_http_request)
        .and_return(failed_response)

      post '/api/v1/loans/import_loans', headers: headers

      expect(response).to have_http_status(:bad_gateway)
      body = json_body
      expect(body['error']).to eq('protext_sync_failed')
    end
  end
end
