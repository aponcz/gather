class SendInviteJob < ApplicationJob
  queue_as :default

  def perform(invite_id)
    invite = Invite.find(invite_id)
    InviteMailer.with(invite: invite).invite_email.deliver_now
    AuditLogger.log!(organization: invite.organization, invite: invite, action: "invite.email_sent")
  end
end
