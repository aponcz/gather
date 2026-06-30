module Api
  module V1
    class InvitesController < ApplicationController
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
        # binding.pry
        # render json: invite.as_json(include: [:contact, :request_items, :audit_events])
        render json: invite.as_json(
  include: {
    contact: {},
    audit_events: {},
    request_items: {
      include: :uploaded_files
    }
  }
)
      end

      def create
        contact = current_organization.contacts.find(params.require(:contact_id))
        invite = current_organization.invites.create!(invite_params.merge(contact: contact, created_by: current_user))
        Array(params[:request_items]).each do |item|
          invite.request_items.create!(item.permit(:title, :description, :kind, :due_at, :required))
        end
        AuditLogger.log!(organization: current_organization, invite: invite, user: current_user, action: "invite.created")
        render json: invite.as_json(include: [:contact, :request_items]), status: :created
      end

      def update
        invite.update!(invite_params)
        AuditLogger.log!(organization: current_organization, invite: invite, user: current_user, action: "invite.updated")
        render json: invite
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

      private

      def invite
        @invite ||= current_organization.invites.find(params[:id])
      end

      def invite_params
        params.permit(:title, :message, :due_at, :brand_color, :logo_url)
      end
    end
  end
end
