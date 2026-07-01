module Api
  module V1
    class RequestItemsController < ApplicationController
      before_action :authenticate_user!

      def create
        item = invite.request_items.create!(item_params)
        AuditLogger.log!(company: current_company, invite: invite, user: current_user, action: "request_item.created", metadata: { request_item_id: item.id })
        render json: item, status: :created
      end

      def update
        item.update!(item_params)
        render json: item
      end

      def destroy
        item.destroy!
        head :no_content
      end

      private

      def invite
        @invite ||= current_company.invites.find(params[:invite_id])
      end

      def item
        @item ||= invite.request_items.find(params[:id])
      end

      def item_params
        params.permit(:title, :description, :kind, :status, :due_at, :required, :section_name)
      end
    end
  end
end
