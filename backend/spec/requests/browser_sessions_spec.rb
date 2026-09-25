require 'rails_helper'

RSpec.describe 'Browser sessions across company hosts', type: :request do
  let!(:company) { Company.create!(name: 'Original', subdomain: "original-#{SecureRandom.hex(4)}") }
  let!(:destination) { Company.create!(name: 'Destination', subdomain: "destination-#{SecureRandom.hex(4)}") }
  let!(:user) { User.create!(company: company, name: 'Browser User', email: "browser-#{SecureRandom.hex(4)}@example.com", password: 'password123', role: 'admin') }
  let!(:membership) { CompanyMembership.create!(company: destination, user: user, role: 'member') }
  let(:token) { JwtService.encode({ sub: user.id, company_id: company.id, type: 'user' }) }
  let(:origin) { 'https://app.gather.stage.goprotext.com' }
  let(:destination_origin) { "https://#{destination.subdomain}.gather.stage.goprotext.com" }
  let(:path) { '/api/v1/auth/browser-session' }

  before do
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with('FRONTEND_BASE_DOMAIN').and_return('gather.stage.goprotext.com')
  end

  def establish_session(from: origin)
    post path, headers: json_headers('Origin' => from, 'Authorization' => "Bearer #{token}")
    expect(response).to have_http_status(:ok)
  end

  it 'restores sign-in on a different company hostname without an Authorization header' do
    establish_session
    get path, headers: { 'Origin' => destination_origin }
    expect(response).to have_http_status(:ok)
    expect(json_body.dig('company', 'id')).to eq(destination.id)
    expect(JwtService.decode(json_body.fetch('token'))['company_id']).to eq(destination.id)
    expect(response.headers['Cache-Control']).to eq('no-store')
    expect(response.headers['Access-Control-Allow-Origin']).to eq(destination_origin)
    expect(response.headers['Access-Control-Allow-Credentials']).to eq('true')
  end

  it 'selects the hostname company when upgrading a legacy token for another company' do
    establish_session(from: destination_origin)
    expect(json_body.dig('company', 'id')).to eq(destination.id)
  end

  it 'sets a host-only HttpOnly cookie rather than sharing the credential with frontend hosts' do
    establish_session
    cookie = Array(response.headers['Set-Cookie']).join(';')
    expect(cookie).to match(/httponly/i)
    expect(cookie).to match(/samesite=lax/i)
    expect(cookie).not_to match(/domain=/i)
  end

  it 'uses a Secure host-prefixed cookie in production' do
    allow(Rails.env).to receive(:production?).and_return(true)
    establish_session
    cookie = Array(response.headers['Set-Cookie']).join(';')
    expect(cookie).to include('__Host-gather_browser_session=')
    expect(cookie).to match(/secure/i)
    expect(cookie).to match(/path=\//i)
  end

  it 'does not fall back to the original company for an unauthorized hostname' do
    establish_session
    membership.destroy!
    get path, headers: { 'Origin' => destination_origin }
    expect(response).to have_http_status(:forbidden)
    expect(json_body).to eq('error' => 'company_access_denied')
  end

  it 'rejects unknown company hostnames' do
    establish_session
    get path, headers: { 'Origin' => 'https://missing.gather.stage.goprotext.com' }
    expect(response).to have_http_status(:forbidden)
  end

  it 'rejects expired cookies' do
    cookies['gather_browser_session'] = JwtService.encode({ sub: user.id, company_id: company.id, type: 'browser_session' }, expires_in: -1.minute)
    get path, headers: { 'Origin' => origin }
    expect(response).to have_http_status(:unauthorized)
  end

  it 'rejects a normal access token used as a browser cookie' do
    cookies['gather_browser_session'] = token
    get path, headers: { 'Origin' => origin }
    expect(response).to have_http_status(:unauthorized)
  end

  it 'does not accept a browser cookie as a general API bearer token' do
    browser_token = JwtService.encode({ sub: user.id, company_id: company.id, type: 'browser_session' })
    get '/api/v1/me', headers: { 'Authorization' => "Bearer #{browser_token}" }
    expect(response).to have_http_status(:unauthorized)
  end

  it 'rejects missing sessions and requires authentication to establish one' do
    get path, headers: { 'Origin' => origin }
    expect(response).to have_http_status(:unauthorized)
    expect(json_body).to eq('error' => 'missing_browser_session')
    post path, headers: json_headers('Origin' => origin)
    expect(response).to have_http_status(:unauthorized)
  end

  it 'removes the cookie when signing out' do
    establish_session
    delete path, headers: json_headers('Origin' => origin)
    expect(response).to have_http_status(:no_content)
    get path, headers: { 'Origin' => destination_origin }
    expect(response).to have_http_status(:unauthorized)
  end

  it 'rejects untrusted or missing origins, including lookalike hostnames' do
    establish_session
    [nil, 'null', 'https://evil.example', 'https://acme.gather.stage.goprotext.com.evil.example', 'http://acme.gather.stage.goprotext.com'].each do |untrusted|
      get path, headers: { 'Origin' => untrusted }
      expect(response).to have_http_status(:forbidden)
      expect(response.headers['Access-Control-Allow-Credentials']).not_to eq('true')
      delete path, headers: json_headers('Origin' => untrusted)
      expect(response).to have_http_status(:forbidden)
    end
    get path, headers: { 'Origin' => destination_origin }
    expect(response).to have_http_status(:ok)
  end
end
