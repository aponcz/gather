require 'rails_helper'
require 'zip'

RSpec.describe 'Loan download all files', type: :request do
  let(:admin_email) { "admin-#{SecureRandom.hex(4)}@acme.test" }
  let(:contact_email) { "client1-#{SecureRandom.hex(4)}@acme.test" }

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
  let!(:contact) do
    Contact.create!(
      company: company,
      name: 'Client One',
      email: contact_email
    )
  end
  let!(:loan) do
    Loan.create!(
      company: company,
      contact: contact,
      created_by: user,
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
  let!(:uploaded_file_one) do
    UploadedFile.create!(
      request_item: request_item,
      uploaded_by_contact: contact,
      storage_key: 'org-1/loan-1/request-1/file-1.pdf',
      filename: 'file-1.pdf',
      content_type: 'application/pdf'
    )
  end
  let!(:uploaded_file_two) do
    UploadedFile.create!(
      request_item: request_item,
      uploaded_by_contact: contact,
      storage_key: 'org-1/loan-1/request-1/file-2.pdf',
      filename: 'file-2.pdf',
      content_type: 'application/pdf'
    )
  end

  let(:token) { JwtService.encode({ sub: user.id, company_id: company.id }, expires_in: 1.hour) }
  let(:headers) { { 'Authorization' => "Bearer #{token}" } }

  describe 'GET /api/v1/loans/:id/download_all_files' do
    it 'returns a zip archive containing all uploaded files for the loan' do
      allow_any_instance_of(StorageService).to receive(:download).with(key: uploaded_file_one.storage_key).and_return('content-one')
      allow_any_instance_of(StorageService).to receive(:download).with(key: uploaded_file_two.storage_key).and_return('content-two')

      get "/api/v1/loans/#{loan.id}/download_all_files", headers: headers

      expect(response).to have_http_status(:ok)
      expect(response.headers['Content-Type']).to include('application/zip')
      expect(response.headers['Content-Disposition']).to include('attachment')

      files = {}
      Zip::File.open_buffer(response.body) do |zip|
        zip.each do |entry|
          files[entry.name] = entry.get_input_stream.read
        end
      end

      expect(files).to eq(
        'Requested items/file-1.pdf' => 'content-one',
        'Requested items/file-2.pdf' => 'content-two'
      )
    end

    it 'organizes files into section folders' do
      # Create request items with different sections
      financial_item = RequestItem.create!(
        loan: loan,
        title: 'Financial Statements',
        kind: 'document',
        required: true,
        section_name: 'Financial Statements'
      )

      personal_item = RequestItem.create!(
        loan: loan,
        title: 'Personal ID',
        kind: 'document',
        required: true,
        section_name: 'Personal Information'
      )

      financial_file = UploadedFile.create!(
        request_item: financial_item,
        uploaded_by_contact: contact,
        storage_key: 'org-1/loan-1/request-2/statement.pdf',
        filename: 'statement.pdf',
        content_type: 'application/pdf'
      )

      personal_file = UploadedFile.create!(
        request_item: personal_item,
        uploaded_by_contact: contact,
        storage_key: 'org-1/loan-1/request-3/id.pdf',
        filename: 'id.pdf',
        content_type: 'application/pdf'
      )

      allow_any_instance_of(StorageService).to receive(:download).with(key: financial_file.storage_key).and_return('financial-content')
      allow_any_instance_of(StorageService).to receive(:download).with(key: personal_file.storage_key).and_return('personal-content')
      allow_any_instance_of(StorageService).to receive(:download).with(key: uploaded_file_one.storage_key).and_return('content-one')
      allow_any_instance_of(StorageService).to receive(:download).with(key: uploaded_file_two.storage_key).and_return('content-two')

      get "/api/v1/loans/#{loan.id}/download_all_files", headers: headers

      expect(response).to have_http_status(:ok)

      files = {}
      Zip::File.open_buffer(response.body) do |zip|
        zip.each do |entry|
          files[entry.name] = entry.get_input_stream.read
        end
      end

      expect(files).to eq(
        'Requested items/file-1.pdf' => 'content-one',
        'Requested items/file-2.pdf' => 'content-two',
        'Financial Statements/statement.pdf' => 'financial-content',
        'Personal Information/id.pdf' => 'personal-content'
      )
    end

    it 'returns unauthorized when token is missing' do
      get "/api/v1/loans/#{loan.id}/download_all_files"

      expect(response).to have_http_status(:unauthorized)
      expect(json_body).to eq({ 'error' => 'missing_token' })
    end
  end
end