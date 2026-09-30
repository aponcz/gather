class LoanMailer < ApplicationMailer
  def loan_email
    @loan = params[:loan]
    @loan_contact = params[:loan_contact]
    @contact = params[:contact] || @loan_contact&.contact || @loan.contact
    recipient_email = @loan_contact&.email || @contact&.email || @loan.primary_recipient_email
    @recipient_name = @loan_contact&.name || @contact&.name
    @company = @loan.company
    @client_url = client_url(@loan, contact: @contact, loan_contact: @loan_contact)
    @preheader = "#{@company.name} requested documents for #{@loan.title}."

    mail(to: recipient_email, subject: "Document request: #{@loan.title}")
  end

  def reminder_email
    @loan = params[:loan]
    recipient_email = @loan.primary_recipient_email
    return if recipient_email.blank?

    loan_contact = primary_loan_contact(@loan)
    contact = @loan.contact || loan_contact&.contact
    @recipient_name = loan_contact&.name || contact&.name
    @company = @loan.company
    @client_url = client_url(@loan, contact: contact, loan_contact: loan_contact)
    @preheader = "A friendly reminder to finish your document request for #{@loan.title}."

    mail(to: recipient_email, subject: "Reminder: #{@loan.title}")
  end

  def daily_uncollected_summary_email
    @loan = params[:loan]
    @pending_items = params[:pending_items] || []

    recipient_email = @loan.primary_recipient_email
    return if recipient_email.blank?

    loan_contact = primary_loan_contact(@loan)
    contact = @loan.contact || loan_contact&.contact
    @recipient_name = loan_contact&.name || contact&.name
    @company = @loan.company
    @client_url = client_url(@loan, contact: contact, loan_contact: loan_contact)
    @preheader = "#{@pending_items.length} document#{'s' unless @pending_items.one?} still need your attention."

    mail(to: recipient_email, subject: "Daily summary: #{@loan.title}")
  end

  private

  def client_url(loan, contact:, loan_contact:)
    base = ENV.fetch("CLIENT_APP_URL", "http://localhost:5173")
    magic_token = client_magic_token(loan, contact: contact, loan_contact: loan_contact)
    "#{base}/client/loans/#{loan.public_token}?magic_token=#{CGI.escape(magic_token)}"
  end

  def client_magic_token(loan, contact:, loan_contact:)
    identity = if contact.present?
      { contact_id: contact.id }
    elsif loan_contact.present?
      { loan_contact_id: loan_contact.id }
    else
      raise ArgumentError, "A contact or loan contact is required to create a client link"
    end

    JwtService.encode(
      identity.merge(company_id: loan.company_id, loan_id: loan.id, type: "client_magic"),
      expires_in: 7.days
    )
  end

  def primary_loan_contact(loan)
    loan.loan_contacts.includes(:contact).first
  end

  def primary_contact(loan)
    loan.contact || primary_loan_contact(loan)&.contact
  end
end
