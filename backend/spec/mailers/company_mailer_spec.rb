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
