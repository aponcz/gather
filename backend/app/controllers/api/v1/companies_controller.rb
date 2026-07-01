module Api
  module V1
    class CompaniesController < ApplicationController
      before_action :authenticate_user!

      def show
        render json: current_company
      end

      def update
        current_company.update!(company_params)
        render json: current_company
      end

      private

      def company_params
        params.require(:company).permit(
          :name,
          :phone_number,
          :address_line_1,
          :address_line_2,
          :city,
          :state,
          :zip_code,
          :website,
          :subdomain,
          :custom_domain,
          :logo,
          :trial_started_on,
          :activated_on,
          :delinquent_on,
          :suspended_on
        )
      end
    end
  end
end
