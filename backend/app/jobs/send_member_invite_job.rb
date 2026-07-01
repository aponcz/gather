class SendMemberInviteJob < ApplicationJob
  queue_as :default

  def perform(member_id, company_id, temporary_password = nil)
    member = User.find(member_id)
    company = Company.find(company_id)
    CompanyMailer.with(member: member, company: company, temporary_password: temporary_password).member_invite_email.deliver_now
  end
end
