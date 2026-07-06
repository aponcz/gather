class SendInviteJob < ApplicationJob
  queue_as :default

  def perform(invite_id, contact_id = nil, invite_contact_id = nil)
    invite = Invite.find(invite_id)

    invite_contact = if invite_contact_id.present?
      invite.invite_contacts.find(invite_contact_id)
    else
      nil
    end

    contact = if invite_contact&.contact.present?
      invite_contact.contact
    elsif contact_id.present?
      Contact.find(contact_id)
    else
      invite.contact
    end

    InviteMailer.with(invite: invite, contact: contact, invite_contact: invite_contact).invite_email.deliver_now
    AuditLogger.log!(
      company: invite.company,
      invite: invite,
      contact: contact,
      action: "invite.email_sent",
      metadata: invite_contact.present? ? { recipient_email: invite_contact.email } : {}
    )
  end
end
