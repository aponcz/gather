class CompanyMailer < ApplicationMailer
  def member_invite_email
    @member = params[:member]
    @company = params[:company] || @member.companies.first || @member.company
    @temporary_password = params[:temporary_password]

    mail(to: @member.email, subject: "You have been invited to #{@company.name}") do |format|
      format.text do
        render plain: <<~TEXT
          You have been invited to join #{@company.name} on Gather.

          Email: #{@member.email}
          #{temporary_password_line}

          Sign in here: #{login_url}
        TEXT
      end
    end
  end

  def password_reset_email
    @user = params[:user]
    @token = params[:token]
    @company = params[:company] || @user.companies.first || @user.company

    mail(to: @user.email, subject: "Reset your Gather password") do |format|
      format.text do
        render plain: <<~TEXT
          We received a request to reset your password for #{@company.name} on Gather.

          Reset your password here: #{reset_password_url(@token)}

          If you did not request this, you can ignore this email.
        TEXT
      end
    end
  end

  private

  def login_url
    base = ENV.fetch("CLIENT_APP_URL", "http://localhost:5173")
    "#{base}/login"
  end

  def reset_password_url(token)
    base = ENV.fetch("CLIENT_APP_URL", "http://localhost:5173")
    "#{base}/reset-password/#{token}"
  end

  def temporary_password_line
    return "Use your existing password to sign in." if @temporary_password.blank?

    "Temporary password: #{@temporary_password}"
  end
end