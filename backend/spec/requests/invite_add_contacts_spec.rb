require 'rails_helper'

RSpec.describe 'Invite add contacts', type: :request do
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

  let!(:invite) do
    Invite.create!(
      company: company,
      contact: contact_one,
      created_by: user,
      title: 'SBA Loan Package',
      status: 'sent'
    )
  end

  let!(:invite_contact) { InviteContact.create!(invite: invite, contact: contact_one) }

  let(:token) { JwtService.encode({ sub: user.id, company_id: company.id }, expires_in: 1.hour) }
  let(:headers) { json_headers('Authorization' => "Bearer #{token}") }

  describe 'POST /api/v1/invites/:id/add_contacts' do
    it 'adds new contacts to an existing invite and queues invite emails for new contacts' do
      allow(SendInviteJob).to receive(:perform_later)

      post "/api/v1/invites/#{invite.id}/add_contacts", params: {
        contact_ids: [contact_two.id]
      }.to_json, headers: headers

      expect(response).to have_http_status(:ok)
      body = json_body
      expect(body['added_contact_count']).to eq(1)
      expect(body.dig('invite', 'contacts').map { |contact| contact['contact_id'] }).to include(contact_two.id)

      expect(invite.reload.invite_contacts.pluck(:email)).to match_array([contact_one.email, contact_two.email])
      expect(SendInviteJob).to have_received(:perform_later).once
    end

    it 'adds non-global recipients directly to an existing invite' do
      allow(SendInviteJob).to receive(:perform_later)

      post "/api/v1/invites/#{invite.id}/add_contacts", params: {
        recipients: [
          { name: 'Extra Borrower', email: "extra-#{SecureRandom.hex(4)}@acme.test" }
        ]
      }.to_json, headers: headers

      expect(response).to have_http_status(:ok)
      body = json_body
      expect(body['added_contact_count']).to eq(1)
      expect(invite.reload.invite_contacts.pluck(:email).any? { |email| email.start_with?('extra-') }).to eq(true)
    end

    it 'returns validation error when contact is missing' do
      post "/api/v1/invites/#{invite.id}/add_contacts", params: {
        contact_ids: [SecureRandom.uuid]
      }.to_json, headers: headers

      expect(response).to have_http_status(:unprocessable_entity)
      body = json_body
      expect(body['error']).to eq('contacts_not_found')
      expect(body['contact_ids'].length).to eq(1)
    end
  end
end
