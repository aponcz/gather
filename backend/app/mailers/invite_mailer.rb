class InviteMailer < ApplicationMailer
  def invite_email
    @invite = params[:invite]
    @invite_contact = params[:invite_contact]
    @contact = params[:contact] || @invite_contact&.contact || @invite.contact
    recipient_email = @invite_contact&.email || @contact&.email || @invite.primary_recipient_email
    mail(to: recipient_email, subject: "Document request: #{@invite.title}") do |format|
      format.text { render plain: "Please complete your request: #{client_url(@invite)}" }
    end
  end

  def reminder_email
    @invite = params[:invite]
    recipient_email = @invite.primary_recipient_email
    return if recipient_email.blank?

    mail(to: recipient_email, subject: "Reminder: #{@invite.title}") do |format|
      format.text { render plain: "Reminder to complete your request: #{client_url(@invite)}" }
    end
  end

  def daily_uncollected_summary_email
    @invite = params[:invite]
    @pending_items = params[:pending_items] || []

    body = <<~TEXT
      Daily summary: You still have documents to submit for "#{@invite.title}".

      Outstanding documents:
      #{@pending_items.map { |item| "- #{item.title}" }.join("\n")}

      Complete your request here: #{client_url(@invite)}
    TEXT

    recipient_email = @invite.primary_recipient_email
    return if recipient_email.blank?

    mail(to: recipient_email, subject: "Daily summary: #{@invite.title}") do |format|
      format.text { render plain: body }
    end
  end

  private

  def client_url(invite)
    base = ENV.fetch("CLIENT_APP_URL", "http://localhost:5173")
    "#{base}/invites/#{invite.public_token}"
  end
end
