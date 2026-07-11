require 'rails_helper'

RSpec.describe DailyUncollectedDocumentsSummaryJob, type: :job do
  describe '#perform' do
    before do
      Loan.destroy_all
      ActionMailer::Base.deliveries.clear
    end

    let(:company) { Company.create!(name: "Summary Co #{SecureRandom.hex(4)}") }
    let(:contact) { Contact.create!(company: company, name: 'Client Contact', email: "client-#{SecureRandom.hex(4)}@example.test") }
    let(:user) do
      User.create!(
        company: company,
        name: 'Admin User',
        email: "admin-#{SecureRandom.hex(4)}@example.test",
        password: 'password123',
        role: 'admin'
      )
    end

    it 'sends summary email for loan with outstanding request items' do
      loan = Loan.create!(company: company, contact: contact, created_by: user, title: "Tax Docs #{SecureRandom.hex(3)}", status: 'sent')
      RequestItem.create!(loan: loan, title: 'W-2', kind: 'document', status: 'pending')

      expect {
        described_class.perform_now
      }.to change { ActionMailer::Base.deliveries.count }.by(1)

      mail = ActionMailer::Base.deliveries.last
      expect(mail.to).to eq([contact.email])
      expect(mail.subject).to eq("Daily summary: #{loan.title}")
      expect(mail.body.encoded).to include('W-2')
    end

    it 'does not send email for completed loan' do
      loan = Loan.create!(company: company, contact: contact, created_by: user, title: "Closed Loan #{SecureRandom.hex(3)}", status: 'completed')
      RequestItem.create!(loan: loan, title: '1099', kind: 'document', status: 'pending')

      expect {
        described_class.perform_now
      }.not_to change { ActionMailer::Base.deliveries.count }
    end
  end
end
