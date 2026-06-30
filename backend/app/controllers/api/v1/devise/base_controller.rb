module Api
  module V1
    module Devise
      class BaseController < ::DeviseController
        respond_to :json

        private

        def token_for(user, company)
          JwtService.encode({ sub: user.id, company_id: company.id, type: "user" })
        end

        def user_payload(user, company)
          user.as_json(only: %i[id name email]).merge(
            "role" => user.role_for(company),
            "company_id" => company.id,
            "company_ids" => user.companies.pluck(:id)
          )
        end

        def auth_payload(user, company)
          {
            token: token_for(user, company),
            user: user_payload(user, company),
            company: company,
            companies: user.companies.order(:name).select(:id, :name)
          }
        end

        def resolve_company_for(user, requested_company_id)
          return user.companies.find(requested_company_id) if requested_company_id.present?

          user.companies.first || user.company || raise(ActiveRecord::RecordNotFound)
        end
      end
    end
  end
end
