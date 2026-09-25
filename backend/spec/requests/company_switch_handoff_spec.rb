require 'rails_helper'

RSpec.describe 'Company switch sign-in handoff', type: :request do
  let!(:company) { Company.create!(name: 'Original') }
  let!(:destination) { Company.create!(name: 'Destination', subdomain: "acme-#{SecureRandom.hex(4)}") }
  let!(:user) { User.create!(company: company, name: 'Switcher', email: "switch-#{SecureRandom.hex(4)}@example.com", password: 'password123', role: 'admin') }
  let!(:membership) { CompanyMembership.create!(company: destination, user: user, role: 'member') }
  let(:headers) { json_headers('Authorization' => "Bearer #{JwtService.encode({ sub: user.id, company_id: company.id, type: 'user' })}") }

  def issue_code
    post '/api/v1/auth/switch-company', params: { company_id: destination.id, handoff: true }.to_json, headers: headers
    expect(response).to have_http_status(:ok)
    expect(json_body).not_to have_key('token')
    json_body.fetch('code')
  end

  def redeem(code)
    post '/api/v1/auth/complete-company-switch', params: { code: code }.to_json, headers: json_headers
  end

  it 'includes company domains in the authenticated company list' do
    get '/api/v1/me', headers: headers
    expect(json_body.fetch('companies').find { |c| c['id'] == destination.id }.fetch('subdomain')).to eq(destination.subdomain)
  end

  it 'requires authentication to issue a code' do
    post '/api/v1/auth/switch-company', params: { company_id: destination.id, handoff: true }.to_json, headers: json_headers
    expect(response).to have_http_status(:unauthorized)
    expect(CompanySignInCode.count).to eq(0)
  end

  it 'filters codes from request logging' do
    filter = ActiveSupport::ParameterFilter.new(Rails.application.config.filter_parameters)
    expect(filter.filter('code' => 'secret')).to eq('code' => '[FILTERED]')
  end

  it 'exchanges a code once for a session scoped to the selected company' do
    code = issue_code
    redeem(code)
    expect(response).to have_http_status(:ok)
    expect(JwtService.decode(json_body.fetch('token')).fetch('company_id')).to eq(destination.id)
    expect(response.headers['Cache-Control']).to eq('no-store')
    redeem(code)
    expect(response).to have_http_status(:unauthorized)
  end

  it 'rejects expired and unknown codes' do
    code = issue_code
    CompanySignInCode.update_all(expires_at: 1.second.ago)
    redeem(code)
    expect(response).to have_http_status(:unauthorized)
    redeem('unknown')
    expect(response).to have_http_status(:unauthorized)
  end

  it 'rechecks membership before creating the new session' do
    code = issue_code
    membership.destroy!
    redeem(code)
    expect(response).to have_http_status(:forbidden)
  end

  it 'does not issue a code for a nonmember' do
    membership.destroy!
    post '/api/v1/auth/switch-company', params: { company_id: destination.id, handoff: true }.to_json, headers: headers
    expect(response).to have_http_status(:forbidden)
    expect(CompanySignInCode.count).to eq(0)
  end
end
