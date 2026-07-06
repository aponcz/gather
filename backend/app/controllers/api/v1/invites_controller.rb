module Api
  module V1
    class InvitesController < ApplicationController
      require "zip"

      before_action :authenticate_user!

      def index
        invites = current_company.invites.includes(:contact, :invite_contacts, { request_items: :uploaded_files }).order(created_at: :desc)
        render json: invites.map { |record| invite_payload(record) }
      end

      def show
        render json: invite_payload(invite, include_audit_events: true)
      end

      def create
        recipients, missing_contact_ids = recipients_from_params
        if missing_contact_ids.any?
          return render json: { error: "contacts_not_found", contact_ids: missing_contact_ids }, status: :unprocessable_entity
        end
        if recipients.empty?
          return render json: { error: "recipients_required" }, status: :unprocessable_entity
        end

        invite = Invite.transaction do
          created_invite = current_company.invites.create!(
            invite_params.merge(
              contact: recipients.first[:contact],
              created_by: current_user
            )
          )
          create_request_items!(created_invite)
          create_invite_recipients!(created_invite, recipients)
          created_invite
        end

        AuditLogger.log!(company: current_company, invite: invite, user: current_user, action: "invite.created")
        render json: invite_payload(invite), status: :created
      end

      def bulk_create
        recipients, missing_contact_ids = recipients_from_params
        if missing_contact_ids.any?
          return render json: { error: "contacts_not_found", contact_ids: missing_contact_ids }, status: :unprocessable_entity
        end
        if recipients.empty?
          return render json: { error: "recipients_required" }, status: :unprocessable_entity
        end

        created_invite = Invite.transaction do
          invite = current_company.invites.create!(invite_params.merge(contact: recipients.first[:contact], created_by: current_user))
          create_request_items!(invite)

          added_recipients = create_invite_recipients!(invite, recipients)

          invite.sent! unless invite.sent?
          added_recipients.each do |invite_contact|
            SendInviteJob.perform_later(invite.id, nil, invite_contact.id)
          end
          AuditLogger.log!(company: current_company, invite: invite, user: current_user, action: "invite.created", metadata: { bulk_contact_count: added_recipients.length })
          invite
        end

        recipient_count = created_invite.invite_contacts.count

        render json: {
          invite: invite_payload(created_invite),
          contact_count: recipient_count,
          message: "Invite created and sent to #{recipient_count} contacts"
        }, status: :created
      end

      def update
        invite.update!(invite_params)
        AuditLogger.log!(company: current_company, invite: invite, user: current_user, action: "invite.updated")
        render json: invite
      end

      def add_contacts
        recipients, missing_contact_ids = recipients_from_params
        if missing_contact_ids.any?
          return render json: { error: "contacts_not_found", contact_ids: missing_contact_ids }, status: :unprocessable_entity
        end
        if recipients.empty?
          return render json: { error: "recipients_required" }, status: :unprocessable_entity
        end

        added_recipients = []

        Invite.transaction do
          recipients.each do |recipient|
            if invite.invite_contacts.where("LOWER(email) = ?", recipient[:email].downcase).exists?
              next
            end

            invite_contact = invite.invite_contacts.create!(
              contact: recipient[:contact],
              name: recipient[:name],
              email: recipient[:email],
              phone: recipient[:phone]
            )
            added_recipients << invite_contact
          end

          added_recipients.each do |invite_contact|
            SendInviteJob.perform_later(invite.id, nil, invite_contact.id)
          end

          AuditLogger.log!(
            company: current_company,
            invite: invite,
            user: current_user,
            action: "invite.contacts_added",
            metadata: { added_contact_count: added_recipients.length }
          )
        end

        render json: {
          invite: invite_payload(invite.reload),
          added_contact_count: added_recipients.length
        }
      end

      def send_invite
        invite.sent! unless invite.sent?
        if invite.invite_contacts.exists?
          invite.invite_contacts.find_each do |recipient|
            SendInviteJob.perform_later(invite.id, nil, recipient.id)
          end
        else
          SendInviteJob.perform_later(invite.id)
        end
        render json: { status: "queued", invite: invite }
      end

      def cancel
        invite.cancelled!
        AuditLogger.log!(company: current_company, invite: invite, user: current_user, action: "invite.cancelled")
        render json: invite
      end

      def download_all_files
        request_items_with_files = invite.request_items.includes(:uploaded_files)
        storage_service = StorageService.new
        used_names = Hash.new(0)

        zip_data = Zip::OutputStream.write_buffer do |zip|
          request_items_with_files.each do |request_item|
            section_name = (request_item.section_name.presence || "Requested items").strip

            request_item.uploaded_files.each do |uploaded_file|
              filename = uploaded_file.filename.presence || "file-#{uploaded_file.id}"
              ext = File.extname(filename)
              basename = File.basename(filename, ext)
              key = "#{section_name}/#{filename}"
              used_names[key] += 1
              entry_name = used_names[key] > 1 ? "#{section_name}/#{basename}-#{used_names[key]}#{ext}" : "#{section_name}/#{filename}"

              zip.put_next_entry(entry_name)
              zip.write(storage_service.download(key: uploaded_file.storage_key))
            end
          end
        end

        zip_data.rewind
        archive_name = "#{invite.title.to_s.parameterize.presence || 'document-collection'}-files.zip"
        send_data zip_data.read, type: "application/zip", disposition: "attachment", filename: archive_name
      end

      private

      def invite
        @invite ||= current_company.invites.find(params[:id])
      end

      def invite_params
        params.permit(:title, :message, :due_at, :brand_color, :logo_url)
      end

      def create_request_items!(invite)
        Array(params[:request_items]).each do |item|
          invite.request_items.create!(item.permit(:title, :description, :kind, :due_at, :required, :section_name))
        end
      end

      def recipients_from_params
        recipients = []
        missing_contact_ids = []

        contact_ids = Array(params[:contact_ids]).map(&:to_s).reject(&:blank?).uniq
        if contact_ids.any?
          contacts = current_company.contacts.where(id: contact_ids).index_by { |contact| contact.id.to_s }
          missing_contact_ids = contact_ids - contacts.keys

          (contact_ids - missing_contact_ids).each do |contact_id|
            contact = contacts.fetch(contact_id)
            recipients << {
              contact: contact,
              name: contact.name,
              email: contact.email,
              phone: contact.phone
            }
          end
        end

        payload_recipients = Array(params[:recipients])
        payload_recipients.each do |recipient|
          recipient_hash = if recipient.respond_to?(:to_unsafe_h)
            recipient.to_unsafe_h
          elsif recipient.respond_to?(:to_h)
            recipient.to_h
          else
            {}
          end

          email = (recipient_hash["email"] || recipient_hash[:email]).to_s.strip.downcase
          next if email.blank?

          name = (recipient_hash["name"] || recipient_hash[:name]).to_s.strip
          phone = (recipient_hash["phone"] || recipient_hash[:phone]).to_s.strip
          recipients << {
            contact: nil,
            name: name.presence || email.split("@").first,
            email: email,
            phone: phone.presence
          }
        end

        recipients = recipients.uniq { |recipient| recipient[:email].downcase }
        [recipients, missing_contact_ids]
      end

      def create_invite_recipients!(invite, recipients)
        recipients.map do |recipient|
          invite.invite_contacts.create!(
            contact: recipient[:contact],
            name: recipient[:name],
            email: recipient[:email],
            phone: recipient[:phone]
          )
        end
      end

      def invite_payload(record, include_audit_events: false)
        payload = record.as_json(
          include: {
            contact: {},
            request_items: {
              include: :uploaded_files
            }
          }
        )
        payload["contacts"] = record.recipient_contacts
        if include_audit_events
          payload["audit_events"] = record.audit_events.order(created_at: :desc).map { |audit_event| audit_event.as_json(methods: :actor_email) }
        end
        payload
      end
    end
  end
end
