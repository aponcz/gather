module Api
  module V1
    class CompaniesController < ApplicationController
      before_action :authenticate_user!
      before_action :authorize_admin_or_god!, only: %i[index]

      def index
        companies = Company.order(:name)
        seen = {}

        unique_companies = companies.select do |company|
          dedupe_key = [
            company.name.to_s.strip.downcase,
            company.subdomain.to_s.strip.downcase,
            company.custom_domain.to_s.strip.downcase
          ]

          next false if seen[dedupe_key]

          seen[dedupe_key] = true
          true
        end

        render json: unique_companies
      end

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

      def authorize_admin_or_god!
        return if %w[admin god].include?(current_user&.role)

        render json: { error: "forbidden" }, status: :forbidden
      end
    end
  end
end
