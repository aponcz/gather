module Api
  module V1
    module Client
      class PortalController < ApplicationController
        before_action :authenticate_client!, except: %i[request_magic_link create_session]

        def request_magic_link
          contact = Contact.find_by!(email: params.require(:email).downcase)
          token = JwtService.encode({ contact_id: contact.id, organization_id: contact.organization_id, type: "client_magic" }, expires_in: 20.minutes)
          # In production, email this token as a link instead of returning it.
          render json: { magic_token: token }
        end

        def create_session
          payload = JwtService.decode(params.require(:magic_token))
          return render(json: { error: "wrong_token_type" }, status: :unauthorized) unless payload["type"] == "client_magic"

          contact = Contact.find(payload.fetch("contact_id"))
          session_token = JwtService.encode({ contact_id: contact.id, organization_id: contact.organization_id, type: "client" }, expires_in: 7.days)
          render json: { token: session_token, contact: contact }
        rescue JWT::DecodeError, ActiveRecord::RecordNotFound, KeyError
          render json: { error: "invalid_magic_token" }, status: :unauthorized
        end

        def show_invite
          invite = @current_contact.invites.find_by!(public_token: params[:id])
          invite.viewed! if invite.sent?
          AuditLogger.log!(organization: invite.organization, invite: invite, contact: @current_contact, action: "invite.viewed", metadata: { ip_address: request.remote_ip, user_agent: request.user_agent })
          render json: invite.as_json(include: { request_items: { include: :uploaded_files } })
        end

        def create_upload_url
          item = @current_contact.invites.joins(:request_items).merge(RequestItem.where(id: params[:id])).first!.request_items.find(params[:id])
          key = "org-#{item.organization.id}/invite-#{item.invite.id}/request-#{item.id}/#{SecureRandom.uuid}-#{params.require(:filename)}"
          url = StorageService.new.presigned_upload_url(key: key, content_type: params.require(:content_type))
          render json: { upload_url: url, storage_key: key }
        end

        def complete_upload
          item = @current_contact.invites.joins(:request_items).merge(RequestItem.where(id: params[:id])).first!.request_items.find(params[:id])
          file = item.uploaded_files.create!(
            uploaded_by_contact: @current_contact,
            storage_key: params.require(:storage_key),
            filename: params.require(:filename),
            content_type: params.require(:content_type),
            byte_size: params[:byte_size]
          )
          AuditLogger.log!(organization: item.organization, invite: item.invite, contact: @current_contact, action: "file.uploaded", metadata: { uploaded_file_id: file.id })
          render json: file, status: :created
        end
      end
    end
  end
end
