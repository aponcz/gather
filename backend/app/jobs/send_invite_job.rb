class SendInviteJob < ApplicationJob
  queue_as :default

  def perform(invite_id, contact_id = nil)
    invite = Invite.find(invite_id)
    contact = contact_id.present? ? Contact.find(contact_id) : invite.contact
    InviteMailer.with(invite: invite, contact: contact).invite_email.deliver_now
    AuditLogger.log!(company: invite.company, invite: invite, contact: contact, action: "invite.email_sent")
  end
end
