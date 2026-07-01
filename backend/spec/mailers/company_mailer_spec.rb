require 'rails_helper'

RSpec.describe CompanyMailer, type: :mailer do
  describe '#password_reset_email' do
    let(:company_name) { "Acme Lending #{SecureRandom.hex(4)}" }
    let(:mailer_email) { "reset-mailer-#{SecureRandom.hex(4)}@acme.test" }
    let!(:company) { Company.create!(name: company_name) }
    let!(:user) do
      User.create!(
        company: company,
        name: 'Reset User',
        email: mailer_email,
        password: 'password123',
        role: 'admin'
      )
    end

    it 'renders recipient, subject, and reset link with token' do
      token = 'abc123token'

      mail = described_class.with(user: user, token: token).password_reset_email

      expect(mail.to).to eq([mailer_email])
      expect(mail.subject).to eq('Reset your Gather password')
      expect(mail.body.encoded).to include(company_name)
      expect(mail.body.encoded).to include("/reset-password/#{token}")
    end
  end
end

RSpec.describe InviteMailer, type: :mailer do
  describe '#daily_uncollected_summary_email' do
    let(:company) { Company.create!(name: "Invite Mailer Co #{SecureRandom.hex(4)}") }
    let(:contact_email) { "invite-contact-#{SecureRandom.hex(4)}@example.test" }
    let(:admin_email) { "invite-admin-#{SecureRandom.hex(4)}@example.test" }
    let(:contact) { Contact.create!(company: company, name: 'Contact', email: contact_email) }
    let(:user) do
      User.create!(
        company: company,
        name: 'Admin',
        email: admin_email,
        password: 'password123',
        role: 'admin'
      )
    end
    let(:invite) { Invite.create!(company: company, contact: contact, created_by: user, title: "Summary Invite #{SecureRandom.hex(3)}", status: 'sent') }
    let(:item) { RequestItem.create!(invite: invite, title: 'Driver License', kind: 'document', status: 'pending') }

    it 'renders recipient, subject, and pending document list' do
      mail = described_class.with(invite: invite, pending_items: [item]).daily_uncollected_summary_email

      expect(mail.to).to eq([contact_email])
      expect(mail.subject).to eq("Daily summary: #{invite.title}")
      expect(mail.body.encoded).to include('Driver License')
      expect(mail.body.encoded).to include(invite.public_token)
    end
  end
end
