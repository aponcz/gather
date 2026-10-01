require 'rails_helper'

RSpec.describe 'Contacts', type: :request do
  let!(:company) { Company.create!(name: "Contact Company #{SecureRandom.hex(3)}") }
  let!(:user) do
    User.create!(
      company: company,
      name: 'Contact Manager',
      email: "contacts-#{SecureRandom.hex(4)}@example.test",
      password: 'password123',
      role: 'admin'
    )
  end
  let(:headers) do
    token = JwtService.encode({ sub: user.id, company_id: company.id }, expires_in: 1.hour)
    json_headers('Authorization' => "Bearer #{token}")
  end
  let!(:contact) { company.contacts.create!(name: 'Original Name', email: 'client@example.test', phone: '555-0100') }

  it 'updates a contact' do
    patch "/api/v1/contacts/#{contact.id}", params: {
      name: 'Updated Name', email: 'updated@example.test', phone: '555-0199'
    }.to_json, headers: headers

    expect(response).to have_http_status(:ok)
    expect(contact.reload).to have_attributes(
      name: 'Updated Name', email: 'updated@example.test', phone: '555-0199', deleted_at: nil
    )
  end

  it 'soft deletes a contact while preserving historical loans and allowing email reuse' do
    loan = company.loans.create!(title: 'Historical loan', created_by: user, contact: contact)

    delete "/api/v1/contacts/#{contact.id}", headers: headers

    expect(response).to have_http_status(:no_content)
    expect(contact.reload.deleted_at).to be_present
    expect(loan.reload.contact).to eq(contact)

    get '/api/v1/contacts', headers: headers
    expect(json_body.map { |item| item['id'] }).not_to include(contact.id)

    replacement = company.contacts.create!(name: 'Replacement', email: contact.email)
    expect(replacement).to be_persisted
  end
end
