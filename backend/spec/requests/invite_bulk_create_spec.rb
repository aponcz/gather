require 'rails_helper'

RSpec.describe 'Invite bulk create', type: :request do
  let(:admin_email) { "admin-#{SecureRandom.hex(4)}@acme.test" }
  let(:contact_one_email) { "client1-#{SecureRandom.hex(4)}@acme.test" }
  let(:contact_two_email) { "client2-#{SecureRandom.hex(4)}@acme.test" }

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

  let!(:contact_one) do
    Contact.create!(
      company: company,
      name: 'Client One',
      email: contact_one_email
    )
  end

  let!(:contact_two) do
    Contact.create!(
      company: company,
      name: 'Client Two',
      email: contact_two_email
    )
  end

  let(:token) { JwtService.encode({ sub: user.id, company_id: company.id }, expires_in: 1.hour) }
  let(:headers) { json_headers('Authorization' => "Bearer #{token}") }

  describe 'POST /api/v1/invites/bulk_create' do
    it 'creates one shared invite with multiple contacts and enqueues invite emails to all' do
      allow(SendInviteJob).to receive(:perform_later)

      post '/api/v1/invites/bulk_create', params: {
        contact_ids: [contact_one.id, contact_two.id],
        title: 'SBA Loan Package',
        message: 'Please upload the requested documents.',
        request_items: [
          { title: 'Tax Returns', kind: 'document', required: true, section_name: 'Financials' },
          { title: 'Bank Statements', kind: 'document', required: true, section_name: 'Financials' }
        ]
      }.to_json, headers: headers

      expect(response).to have_http_status(:created)
      body = json_body
      expect(body['contact_count']).to eq(2)
      expect(body['message']).to include('2 contacts')

      # Only one invite should be created
      created_invites = company.invites.where(title: 'SBA Loan Package')
      expect(created_invites.count).to eq(1)

      invite = created_invites.first
      expect(invite.status).to eq('sent')
      expect(invite.request_items.count).to eq(2)
      expect(invite.request_items.pluck(:section_name).uniq).to eq(['Financials'])

      # Both contacts should be in invite_contacts
      expect(invite.invite_contacts.pluck(:contact_id)).to match_array([contact_one.id, contact_two.id])

      # Invite should be sent to both contacts (SendInviteJob called twice)
      expect(SendInviteJob).to have_received(:perform_later).twice
    end

    it 'returns validation error when any contact is missing' do
      post '/api/v1/invites/bulk_create', params: {
        contact_ids: [contact_one.id, SecureRandom.uuid],
        title: 'SBA Loan Package',
        request_items: []
      }.to_json, headers: headers

      expect(response).to have_http_status(:unprocessable_entity)
      body = json_body
      expect(body['error']).to eq('contacts_not_found')
      expect(body['contact_ids'].length).to eq(1)
    end
  end
end
