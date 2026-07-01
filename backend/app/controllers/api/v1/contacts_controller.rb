module Api
  module V1
    class ContactsController < ApplicationController
      before_action :authenticate_user!

      def index
        render json: current_company.contacts.order(created_at: :desc)
      end

      def show
        render json: contact
      end

      def create
        render json: current_company.contacts.create!(contact_params), status: :created
      end

      def update
        contact.update!(contact_params)
        render json: contact
      end

      private

      def contact
        @contact ||= current_company.contacts.find(params[:id])
      end

      def contact_params
        params.permit(:name, :email, :phone, :external_id)
      end
    end
  end
end
