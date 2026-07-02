module Api
  module V1
    module Devise
      class RegistrationsController < BaseController
        def create
          company = find_company_for_registration
          user = User.new(sign_up_params.merge(company: company, role: default_role_for(company)))

          if user.save
            company.company_memberships.find_or_create_by!(user: user) { |membership| membership.role = user.membership_role }
            render json: auth_payload(user, company), status: :created
          else
            render json: { error: "validation_failed", details: user.errors.full_messages }, status: :unprocessable_entity
          end
        end

        private

        def sign_up_params
          params.require(:user).permit(:name, :email, :password, :password_confirmation)
        end

        def registration_company_params
          params.require(:user).permit(:company_id, :company_name)
        end

        def find_company_for_registration
          attrs = registration_company_params
          return Company.find(attrs[:company_id]) if attrs[:company_id].present?
          return Company.create!(name: attrs[:company_name]) if attrs[:company_name].present?

          raise ActionController::ParameterMissing, :company_name
        end

        def default_role_for(company)
          company.users.exists? ? "member" : "admin"
        end
      end
    end
  end
end
