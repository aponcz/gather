require 'rails_helper'

RSpec.describe 'Client uploaded file download URL', type: :request do
  let(:admin_email) { "admin-#{SecureRandom.hex(4)}@acme.test" }
  let(:contact_email) { "client1-#{SecureRandom.hex(4)}@acme.test" }
  let(:other_contact_email) { "client2-#{SecureRandom.hex(4)}@acme.test" }

  let!(:company) { Company.create!(name: "Acme Lending #{SecureRandom.hex(4)}") }
  let!(:creator) do
    User.create!(
      company: company,
      name: 'Admin User',
      email: admin_email,
      password: 'password123',
      role: 'admin'
    )
  end

  let!(:contact) do
    Contact.create!(
      company: company,
      name: 'Client One',
      email: contact_email
    )
  end

  let!(:other_contact) do
    Contact.create!(
      company: company,
      name: 'Client Two',
      email: other_contact_email
    )
  end

  let!(:loan) do
    Loan.create!(
      company: company,
      contact: contact,
      created_by: creator,
      title: 'SBA Loan Package'
    )
  end

  let!(:request_item) do
    RequestItem.create!(
      loan: loan,
      title: 'Tax Returns',
      kind: 'document',
      required: true
    )
  end

  let!(:uploaded_file) do
    UploadedFile.create!(
      request_item: request_item,
      uploaded_by_contact: contact,
      storage_key: 'org-1/loan-1/request-1/file.pdf',
      filename: 'file.pdf',
      content_type: 'application/pdf'
    )
  end

  let(:client_token) do
    JwtService.encode(
      { contact_id: contact.id, company_id: company.id, type: 'client' },
      expires_in: 1.hour
    )
  end

  let(:other_client_token) do
    JwtService.encode(
      { contact_id: other_contact.id, company_id: company.id, type: 'client' },
      expires_in: 1.hour
    )
  end

  let(:headers) { { 'Authorization' => "Bearer #{client_token}" } }

  describe 'GET /api/v1/client/uploaded-files/:id/download_url' do
    it 'returns a presigned download url for a file owned by the current contact loan' do
      allow_any_instance_of(StorageService)
        .to receive(:presigned_download_url)
        .with(key: uploaded_file.storage_key)
        .and_return('https://download.example.com/file.pdf')

      get "/api/v1/client/uploaded-files/#{uploaded_file.id}/download_url", headers: headers

      expect(response).to have_http_status(:ok)
      expect(json_body).to eq({ 'url' => 'https://download.example.com/file.pdf' })
    end

    it 'returns unauthorized when client token is missing' do
      get "/api/v1/client/uploaded-files/#{uploaded_file.id}/download_url"

      expect(response).to have_http_status(:unauthorized)
      expect(json_body).to eq({ 'error' => 'missing_token' })
    end

    it 'returns not found when file does not belong to current contact loans' do
      get "/api/v1/client/uploaded-files/#{uploaded_file.id}/download_url", headers: { 'Authorization' => "Bearer #{other_client_token}" }

      expect(response).to have_http_status(:not_found)
      expect(json_body).to eq({ 'error' => 'not_found' })
    end
  end
end