module Api
  module V1
    module Client
      class PortalController < ApplicationController
        before_action :authenticate_client!, except: %i[request_magic_link create_session]

        def request_magic_link
          contact = Contact.find_by!(email: params.require(:email).downcase)
          token = JwtService.encode({ contact_id: contact.id, company_id: contact.company_id, type: "client_magic" }, expires_in: 20.minutes)
          # In production, email this token as a link instead of returning it.
          render json: { magic_token: token }
        end

        def create_session
          payload = JwtService.decode(params.require(:magic_token))
          return render(json: { error: "wrong_token_type" }, status: :unauthorized) unless payload["type"] == "client_magic"

          contact = Contact.find(payload.fetch("contact_id"))
          session_token = JwtService.encode({ contact_id: contact.id, company_id: contact.company_id, type: "client" }, expires_in: 7.days)
          render json: { token: session_token, contact: contact }
        rescue JWT::DecodeError, ActiveRecord::RecordNotFound, KeyError
          render json: { error: "invalid_magic_token" }, status: :unauthorized
        end

        def show_invite
          invite = find_accessible_invite(params[:id])
          invite.viewed! if invite.sent?
          AuditLogger.log!(company: invite.company, invite: invite, contact: @current_contact, action: "invite.viewed", metadata: { ip_address: request.remote_ip, user_agent: request.user_agent })
          render json: invite.as_json(include: { contact: {}, contacts: {}, request_items: { include: :uploaded_files } })
        end

        def create_upload_url
          invite = find_accessible_invite_by_request_item(params[:id])
          item = invite.request_items.find(params[:id])
          key = "company-#{item.company.id}/invite-#{item.invite.id}/request-#{item.id}/#{SecureRandom.uuid}-#{params.require(:filename)}"
          url = StorageService.new.presigned_upload_url(key: key, content_type: params.require(:content_type))
          render json: { upload_url: url, storage_key: key }
        end

        def complete_upload
          invite = find_accessible_invite_by_request_item(params[:id])
          item = invite.request_items.find(params[:id])
          file = item.uploaded_files.create!(
            uploaded_by_contact: @current_contact,
            storage_key: params.require(:storage_key),
            filename: params.require(:filename),
            content_type: params.require(:content_type),
            byte_size: params[:byte_size]
          )
          AuditLogger.log!(company: item.company, invite: item.invite, contact: @current_contact, action: "file.uploaded", metadata: { uploaded_file_id: file.id, filename: file.filename })
          render json: file, status: :created
        end

        def download_url
          render json: { url: StorageService.new.presigned_download_url(key: uploaded_file.storage_key) }
        end

        private

        def find_accessible_invite(public_token)
          # Support both old single-contact invites and new shared invites
          Invite.where(public_token: public_token)
            .where(
              'contact_id = :contact_id OR id IN (SELECT invite_id FROM invite_contacts WHERE contact_id = :contact_id OR LOWER(email) = :email)',
              contact_id: @current_contact.id,
              email: @current_contact.email.to_s.downcase
            )
            .first! || raise(ActiveRecord::RecordNotFound)
        end

        def find_accessible_invite_by_request_item(request_item_id)
          # Support both old single-contact and new shared invites for request items
          RequestItem.where(id: request_item_id)
            .joins(:invite)
            .where(
              'invites.contact_id = :contact_id OR invites.id IN (SELECT invite_id FROM invite_contacts WHERE contact_id = :contact_id OR LOWER(email) = :email)',
              contact_id: @current_contact.id,
              email: @current_contact.email.to_s.downcase
            )
            .first!&.invite || raise(ActiveRecord::RecordNotFound)
        end

        def uploaded_file
          @uploaded_file ||= UploadedFile.joins(request_item: :invite)
            .where(id: params[:id])
            .where(
              'invites.contact_id = :contact_id OR invites.id IN (SELECT invite_id FROM invite_contacts WHERE contact_id = :contact_id OR LOWER(email) = :email)',
              contact_id: @current_contact.id,
              email: @current_contact.email.to_s.downcase
            )
            .first! || raise(ActiveRecord::RecordNotFound)
        end
      end
    end
  end
end
