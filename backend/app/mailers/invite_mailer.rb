class InviteMailer < ApplicationMailer
  def invite_email
    @invite = params[:invite]
    @contact = params[:contact] || @invite.contact
    mail(to: @contact.email, subject: "Document request: #{@invite.title}") do |format|
      format.text { render plain: "Please complete your request: #{client_url(@invite)}" }
    end
  end

  def reminder_email
    @invite = params[:invite]
    mail(to: @invite.contact.email, subject: "Reminder: #{@invite.title}") do |format|
      format.text { render plain: "Reminder to complete your request: #{client_url(@invite)}" }
    end
  end

  private

  def client_url(invite)
    base = ENV.fetch("CLIENT_APP_URL", "http://localhost:5173")
    "#{base}/invites/#{invite.public_token}"
  end
end
