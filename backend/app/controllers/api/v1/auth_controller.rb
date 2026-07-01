module Api
  module V1
    class AuthController < ApplicationController
      RESET_PASSWORD_TTL = 2.hours
      RESET_PASSWORD_CACHE_PREFIX = "password-reset"

      before_action :authenticate_user!, only: %i[me switch_company]

      def register
        company = Company.create!(company_registration_params)
        user = User.create!(
          company: company,
          name: params.require(:name),
          email: params.require(:email).downcase,
          password: params.require(:password),
          role: :admin
        )
        company.company_memberships.find_or_create_by!(user: user) { |membership| membership.role = "admin" }
        render_auth_payload(user, company, status: :created)
      end

      def login
        user = authenticate_by_email(params.require(:email), params.require(:password))
        return render(json: { error: "invalid_credentials" }, status: :unauthorized) if user.blank?

        company = resolve_login_company!(user)

        user.update_column(:last_login_at, Time.current)

        render_auth_payload(user, company)
      end

      def me
        render json: {
          user: user_payload(current_user, company: current_company),
          company: current_company,
          companies: companies_payload(current_user)
        }
      end

      def switch_company
        company = current_user.companies.find_by(id: params.require(:company_id))
        return render(json: { error: "forbidden" }, status: :forbidden) if company.blank?

        render_auth_payload(current_user, company)
      end

      def forgot_password
        user = User.find_by(email: params.require(:email).downcase)

        if user.present?
          token = SecureRandom.urlsafe_base64(48)
          cache_reset_token(token, user.id)
          company = user.companies.first || user.company
          CompanyMailer.with(user: user, company: company, token: token).password_reset_email.deliver_later
        end

        render json: { message: "If an account exists with that email, reset instructions have been sent." }
      end

      def reset_password
        token = params.require(:token).to_s
        password = params.require(:password).to_s

        return render(json: { error: "Password must be at least 8 characters" }, status: :unprocessable_entity) if password.length < 8

        user = user_for_reset_token(token)
        return render(json: { error: "Invalid or expired reset token" }, status: :unprocessable_entity) if user.blank?

        user.update!(password: password)
        clear_reset_token(token)

        render json: { message: "Password reset successful" }
      end

      private

      def token_for(user, company)
        JwtService.encode({ sub: user.id, company_id: company.id, type: "user" })
      end

      def user_payload(user, company:)
        user.as_json(only: %i[id name email]).merge(
          "role" => user.role_for(company),
          "company_id" => company.id,
          "company_ids" => user.companies.pluck(:id)
        )
      end

      def render_auth_payload(user, company, status: :ok)
        render json: {
          token: token_for(user, company),
          user: user_payload(user, company: company),
          company: company,
          companies: companies_payload(user)
        }, status: status
      end

      def companies_payload(user)
        user.companies.order(:name).select(:id, :name)
      end

      def resolve_login_company!(user)
        requested_company_id = params[:company_id].presence
        return user.companies.find(requested_company_id) if requested_company_id.present?

        user.companies.first || user.company || raise(ActiveRecord::RecordNotFound)
      end

      def authenticate_by_email(email, password)
        normalized_email = email.to_s.downcase
        User.where("LOWER(email) = ?", normalized_email).find { |candidate| candidate.authenticate(password) }
      end

      def company_registration_params
        permitted = params.permit(
          :company_name,
          :phone_number,
          :address_line_1,
          :address_line_2,
          :city,
          :state,
          :zip_code,
          :website,
          :subdomain,
          :status,
          :logo,
          :trial_started_on,
          :activated_on,
          :delinquent_on,
          :suspended_on
        )

        {
          name: permitted[:company_name],
          phone_number: permitted[:phone_number],
          address_line_1: permitted[:address_line_1],
          address_line_2: permitted[:address_line_2],
          city: permitted[:city],
          state: permitted[:state],
          zip_code: permitted[:zip_code],
          website: permitted[:website],
          subdomain: permitted[:subdomain],
          status: permitted[:status],
          logo: permitted[:logo],
          trial_started_on: permitted[:trial_started_on],
          activated_on: permitted[:activated_on],
          delinquent_on: permitted[:delinquent_on],
          suspended_on: permitted[:suspended_on]
        }.compact_blank
      end

      def cache_reset_token(token, user_id)
        Rails.cache.write(reset_cache_key(token), user_id, expires_in: RESET_PASSWORD_TTL)
      end

      def user_for_reset_token(token)
        user_id = Rails.cache.read(reset_cache_key(token))
        return nil if user_id.blank?

        User.find_by(id: user_id)
      end

      def clear_reset_token(token)
        Rails.cache.delete(reset_cache_key(token))
      end

      def reset_cache_key(token)
        "#{RESET_PASSWORD_CACHE_PREFIX}:#{token}"
      end
    end
  end
end
