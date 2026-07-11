class SendLoanInviteJob < ApplicationJob
  queue_as :default

  def perform(loan_id, contact_id = nil, loan_contact_id = nil)
    loan = Loan.find(loan_id)

    loan_contact = if loan_contact_id.present?
      loan.loan_contacts.find(loan_contact_id)
    else
      nil
    end

    contact = if loan_contact&.contact.present?
      loan_contact.contact
    elsif contact_id.present?
      Contact.find(contact_id)
    else
      loan.contact
    end

    LoanMailer.with(loan: loan, contact: contact, loan_contact: loan_contact).loan_email.deliver_now
    AuditLogger.log!(
      company: loan.company,
      loan: loan,
      contact: contact,
      action: "loan.email_sent",
      metadata: loan_contact.present? ? { recipient_email: loan_contact.email } : {}
    )
  end
end
