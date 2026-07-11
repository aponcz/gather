class LoanMailer < ApplicationMailer
  def loan_email
    @loan = params[:loan]
    @loan_contact = params[:loan_contact]
    @contact = params[:contact] || @loan_contact&.contact || @loan.contact
    recipient_email = @loan_contact&.email || @contact&.email || @loan.primary_recipient_email
    mail(to: recipient_email, subject: "Document request: #{@loan.title}") do |format|
      format.text { render plain: "Please complete your request: #{client_url(@loan)}" }
    end
  end

  def reminder_email
    @loan = params[:loan]
    recipient_email = @loan.primary_recipient_email
    return if recipient_email.blank?

    mail(to: recipient_email, subject: "Reminder: #{@loan.title}") do |format|
      format.text { render plain: "Reminder to complete your request: #{client_url(@loan)}" }
    end
  end

  def daily_uncollected_summary_email
    @loan = params[:loan]
    @pending_items = params[:pending_items] || []

    body = <<~TEXT
      Daily summary: You still have documents to submit for "#{@loan.title}".

      Outstanding documents:
      #{@pending_items.map { |item| "- #{item.title}" }.join("\n")}

      Complete your request here: #{client_url(@loan)}
    TEXT

    recipient_email = @loan.primary_recipient_email
    return if recipient_email.blank?

    mail(to: recipient_email, subject: "Daily summary: #{@loan.title}") do |format|
      format.text { render plain: body }
    end
  end

  private

  def client_url(loan)
    base = ENV.fetch("CLIENT_APP_URL", "http://localhost:5173")
    "#{base}/client/loans/#{loan.public_token}"
  end
end
