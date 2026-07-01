module Api
  module V1
    module Devise
      class SessionsController < BaseController
        def create
          user = authenticate_by_email(session_params.fetch(:email), session_params.fetch(:password))
          return render(json: { error: "invalid_credentials" }, status: :unauthorized) if user.blank?

          company = resolve_company_for(user, session_params[:company_id])
          user.update_column(:last_login_at, Time.current)

          render json: auth_payload(user, company)
        rescue KeyError, ActionController::ParameterMissing
          render json: { error: "invalid_credentials" }, status: :unauthorized
        end

        def destroy
          head :no_content
        end

        private

        def session_params
          params.require(:user).permit(:email, :password, :company_id)
        end

        def authenticate_by_email(email, password)
          normalized_email = email.to_s.downcase
          User.where("LOWER(email) = ?", normalized_email).find { |candidate| candidate.authenticate(password) }
        end
      end
    end
  end
end
