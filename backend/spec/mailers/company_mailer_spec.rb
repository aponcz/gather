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
      expect(JSON.parse(mail['X-SMTPAPI'].value)).to eq(
        'filters' => {
          'clicktrack' => {
            'settings' => { 'enable' => 0, 'enable_text' => false }
          }
        }
      )
    end
  end
end

RSpec.describe LoanMailer, type: :mailer do
  describe '#daily_uncollected_summary_email' do
    let(:company) { Company.create!(name: "Loan Mailer Co #{SecureRandom.hex(4)}") }
    let(:contact_email) { "loan-contact-#{SecureRandom.hex(4)}@example.test" }
    let(:admin_email) { "loan-admin-#{SecureRandom.hex(4)}@example.test" }
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
    let(:loan) { Loan.create!(company: company, contact: contact, created_by: user, title: "Summary Loan #{SecureRandom.hex(3)}", status: 'sent') }
    let(:item) { RequestItem.create!(loan: loan, title: 'Driver License', kind: 'document', status: 'pending') }

    it 'renders recipient, subject, and pending document list' do
      mail = described_class.with(loan: loan, pending_items: [item]).daily_uncollected_summary_email

      expect(mail.to).to eq([contact_email])
      expect(mail.subject).to eq("Daily summary: #{loan.title}")
      expect(mail).to be_multipart
      expect(mail.text_part.body.decoded).to include('Driver License', loan.public_token)
      expect(mail.html_part.body.decoded).to include('ProText <strong>Gather</strong>')
      expect(mail.html_part.body.decoded).to include('Upload remaining documents')
      expect(mail.html_part.body.decoded).to include('clicktracking="off"')
      magic_token = CGI.unescape(mail.text_part.body.decoded.match(/\?magic_token=([^\s]+)/)[1])
      payload = JwtService.decode(magic_token)
      expect(payload).to include('type' => 'client_magic', 'contact_id' => contact.id, 'loan_id' => loan.id)
    end

    it 'creates a usable magic link for a recipient without a global contact' do
      direct_loan = Loan.create!(
        company: company,
        created_by: user,
        title: 'Direct recipient loan',
        message: 'Please upload your latest statements.',
        loan_amount_in_cents: 25_000_000,
        loan_type: 'SBA 7(a)',
        due_at: 1.week.from_now,
        status: 'sent'
      )
      loan_contact = LoanContact.create!(loan: direct_loan, name: 'Direct Recipient', email: 'direct@example.test')

      mail = described_class.with(loan: direct_loan, loan_contact: loan_contact).loan_email

      expect(mail).to be_multipart
      expect(mail.html_part.body.decoded).to include('Everything you need')
      expect(mail.html_part.body.decoded).to include('View document request')
      expect(mail.html_part.body.decoded).to include('$250,000.00', 'SBA 7(a)')
      magic_token = CGI.unescape(mail.text_part.body.decoded.match(/\?magic_token=([^\s]+)/)[1])
      payload = JwtService.decode(magic_token)
      expect(payload).to include('type' => 'client_magic', 'loan_contact_id' => loan_contact.id, 'loan_id' => direct_loan.id)
    end

    it 'renders a branded multipart reminder' do
      mail = described_class.with(loan: loan).reminder_email

      expect(mail).to be_multipart
      expect(mail.text_part.body.decoded).to include('reminder', loan.public_token)
      expect(mail.html_part.body.decoded).to include('Friendly reminder', 'Continue your request')
      expect(mail.html_part.body.decoded).to include('ProText <strong>Gather</strong>')
    end
  end
end
