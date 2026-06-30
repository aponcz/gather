require 'rails_helper'

RSpec.describe 'Invite add contacts', type: :request do
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

  let!(:contact_one) do
    Contact.create!(
      organization: organization,
      name: 'Client One',
      email: 'client1@acme.test'
    )
  end

  let!(:contact_two) do
    Contact.create!(
      organization: organization,
      name: 'Client Two',
      email: 'client2@acme.test'
    )
  end

  let!(:invite) do
    Invite.create!(
      organization: organization,
      contact: contact_one,
      created_by: user,
      title: 'SBA Loan Package',
      status: 'sent'
    )
  end

  let!(:invite_contact) { InviteContact.create!(invite: invite, contact: contact_one) }

  let(:token) { JwtService.encode({ sub: user.id, organization_id: organization.id }, expires_in: 1.hour) }
  let(:headers) { { 'Authorization' => "Bearer #{token}", 'Content-Type' => 'application/json' } }

  describe 'POST /api/v1/invites/:id/add_contacts' do
    it 'adds new contacts to an existing invite and queues invite emails for new contacts' do
      allow(SendInviteJob).to receive(:perform_later)

      post "/api/v1/invites/#{invite.id}/add_contacts", params: {
        contact_ids: [contact_two.id]
      }.to_json, headers: headers

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body['added_contact_count']).to eq(1)
      expect(body.dig('invite', 'contacts').map { |contact| contact['id'] }).to include(contact_two.id)

      expect(invite.reload.invite_contacts.pluck(:contact_id)).to match_array([contact_one.id, contact_two.id])
      expect(SendInviteJob).to have_received(:perform_later).with(invite.id, contact_two.id).once
    end

    it 'returns validation error when contact is missing' do
      post "/api/v1/invites/#{invite.id}/add_contacts", params: {
        contact_ids: [SecureRandom.uuid]
      }.to_json, headers: headers

      expect(response).to have_http_status(:unprocessable_entity)
      body = JSON.parse(response.body)
      expect(body['error']).to eq('contacts_not_found')
      expect(body['contact_ids'].length).to eq(1)
    end
  end
end
