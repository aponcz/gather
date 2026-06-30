module Api
  module V1
    class InvitesController < ApplicationController
      require "zip"

      before_action :authenticate_user!

      def index
        render json: current_organization.invites.includes(:contact, request_items: :uploaded_files).order(created_at: :desc).as_json(
          include: {
            contact: {},
            request_items: {
              include: :uploaded_files
            }
          }
        )
      end

      def show
        render json: invite.as_json(
          include: {
            contact: {},
            contacts: {},
            audit_events: {
              methods: :actor_email
            },
            request_items: {
              include: :uploaded_files
            }
          }
        ).merge(
          "audit_events" => invite.audit_events.order(created_at: :desc).map { |audit_event| audit_event.as_json(methods: :actor_email) }
        )
      end

      def create
        contact = current_organization.contacts.find(params.require(:contact_id))
        invite = current_organization.invites.create!(invite_params.merge(contact: contact, created_by: current_user))
        invite.invite_contacts.create!(contact: contact) unless invite.invite_contacts.exists?(contact: contact)
        create_request_items!(invite)
        AuditLogger.log!(organization: current_organization, invite: invite, user: current_user, action: "invite.created")
        render json: invite.as_json(include: [:contact, { contacts: {} }, :request_items]), status: :created
      end

      def bulk_create
        contact_ids = Array(params[:contact_ids]).map(&:to_s).reject(&:blank?).uniq
        raise ActionController::ParameterMissing, :contact_ids if contact_ids.empty?

        contacts = current_organization.contacts.where(id: contact_ids).index_by { |contact| contact.id.to_s }
        missing_contact_ids = contact_ids - contacts.keys
        return render json: { error: "contacts_not_found", contact_ids: missing_contact_ids }, status: :unprocessable_entity if missing_contact_ids.any?

        created_invite = Invite.transaction do
          primary_contact = contacts.fetch(contact_ids.first)
          invite = current_organization.invites.create!(invite_params.merge(contact: primary_contact, created_by: current_user))
          create_request_items!(invite)

          contact_ids.each do |contact_id|
            invite.invite_contacts.create!(contact: contacts.fetch(contact_id))
          end

          invite.sent! unless invite.sent?
          contact_ids.each do |contact_id|
            SendInviteJob.perform_later(invite.id)
          end
          AuditLogger.log!(organization: current_organization, invite: invite, user: current_user, action: "invite.created", metadata: { bulk_contact_count: contact_ids.length })
          invite
        end

        render json: {
          invite: created_invite.as_json(include: [:contact, { contacts: {} }, :request_items]),
          contact_count: contact_ids.length,
          message: "Invite created and sent to #{contact_ids.length} contacts"
        }, status: :created
      end

      def update
        invite.update!(invite_params)
        AuditLogger.log!(organization: current_organization, invite: invite, user: current_user, action: "invite.updated")
        render json: invite
      end

      def add_contacts
        contact_ids = Array(params[:contact_ids]).map(&:to_s).reject(&:blank?).uniq
        raise ActionController::ParameterMissing, :contact_ids if contact_ids.empty?

        contacts = current_organization.contacts.where(id: contact_ids).index_by { |contact| contact.id.to_s }
        missing_contact_ids = contact_ids - contacts.keys
        return render json: { error: "contacts_not_found", contact_ids: missing_contact_ids }, status: :unprocessable_entity if missing_contact_ids.any?

        added_contacts = []

        Invite.transaction do
          contact_ids.each do |contact_id|
            contact = contacts.fetch(contact_id)
            next if invite.invite_contacts.exists?(contact_id: contact.id)

            invite.invite_contacts.create!(contact: contact)
            added_contacts << contact
          end

          added_contacts.each do |contact|
            SendInviteJob.perform_later(invite.id, contact.id)
          end

          AuditLogger.log!(
            organization: current_organization,
            invite: invite,
            user: current_user,
            action: "invite.contacts_added",
            metadata: { added_contact_count: added_contacts.length }
          )
        end

        render json: {
          invite: invite.as_json(include: [:contact, { contacts: {} }, :request_items]),
          added_contact_count: added_contacts.length
        }
      end

      def send_invite
        invite.sent! unless invite.sent?
        SendInviteJob.perform_later(invite.id)
        render json: { status: "queued", invite: invite }
      end

      def cancel
        invite.cancelled!
        AuditLogger.log!(organization: current_organization, invite: invite, user: current_user, action: "invite.cancelled")
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
        @invite ||= current_organization.invites.find(params[:id])
      end

      def invite_params
        params.permit(:title, :message, :due_at, :brand_color, :logo_url)
      end

      def create_request_items!(invite)
        Array(params[:request_items]).each do |item|
          invite.request_items.create!(item.permit(:title, :description, :kind, :due_at, :required, :section_name))
        end
      end
    end
  end
end
