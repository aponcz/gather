class AuditLogger
  def self.log!(organization:, action:, invite: nil, user: nil, contact: nil, metadata: {})
    AuditEvent.create!(
      organization: organization,
      invite: invite,
      user: user,
      contact: contact,
      action: action,
      ip_address: metadata.delete(:ip_address),
      user_agent: metadata.delete(:user_agent),
      metadata: metadata
    )
  end
end
