require 'rails_helper'
require 'zip'

RSpec.describe 'Invite download all files', type: :request do
  let!(:organization) { Organization.create!(name: 'Acme Lending') }
  let!(:user) do
    User.create!(
      organization: organization,
      name: 'Admin User',
      email: 'admin@acme.test',
      password: 'password123',
      role: 'admin'
    )
  end
  let!(:contact) do
    Contact.create!(
      organization: organization,
      name: 'Client One',
      email: 'client1@acme.test'
    )
  end
  let!(:invite) do
    Invite.create!(
      organization: organization,
      contact: contact,
      created_by: user,
      title: 'SBA Loan Package'
    )
  end
  let!(:request_item) do
    RequestItem.create!(
      invite: invite,
      title: 'Tax Returns',
      kind: 'document',
      required: true
    )
  end
  let!(:uploaded_file_one) do
    UploadedFile.create!(
      request_item: request_item,
      uploaded_by_contact: contact,
      storage_key: 'org-1/invite-1/request-1/file-1.pdf',
      filename: 'file-1.pdf',
      content_type: 'application/pdf'
    )
  end
  let!(:uploaded_file_two) do
    UploadedFile.create!(
      request_item: request_item,
      uploaded_by_contact: contact,
      storage_key: 'org-1/invite-1/request-1/file-2.pdf',
      filename: 'file-2.pdf',
      content_type: 'application/pdf'
    )
  end

  let(:token) { JwtService.encode({ sub: user.id, organization_id: organization.id }, expires_in: 1.hour) }
  let(:headers) { { 'Authorization' => "Bearer #{token}" } }

  describe 'GET /api/v1/invites/:id/download_all_files' do
    it 'returns a zip archive containing all uploaded files for the invite' do
      allow_any_instance_of(StorageService).to receive(:download).with(key: uploaded_file_one.storage_key).and_return('content-one')
      allow_any_instance_of(StorageService).to receive(:download).with(key: uploaded_file_two.storage_key).and_return('content-two')

      get "/api/v1/invites/#{invite.id}/download_all_files", headers: headers

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
        'file-1.pdf' => 'content-one',
        'file-2.pdf' => 'content-two'
      )
    end

    it 'returns unauthorized when token is missing' do
      get "/api/v1/invites/#{invite.id}/download_all_files"

      expect(response).to have_http_status(:unauthorized)
      expect(JSON.parse(response.body)).to eq({ 'error' => 'missing_token' })
    end
  end
end