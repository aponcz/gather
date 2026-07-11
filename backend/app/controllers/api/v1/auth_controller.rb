module Api
  module V1
    class AuthController < ApplicationController
      require "net/http"
      require "uri"
      require "json"

      RESET_PASSWORD_TTL = 2.hours
      RESET_PASSWORD_CACHE_PREFIX = "password-reset"
      OAUTH_STATE_TTL = 10.minutes
      OAUTH_STATE_CACHE_PREFIX = "oauth:goprotext:state"

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

      def oauth_goprotext_start
        state = SecureRandom.urlsafe_base64(32)
        cache_oauth_state(state)

        authorize_uri = URI(goprotext_authorize_url)
        authorize_query = {
          response_type: "code",
          client_id: goprotext_client_id,
          redirect_uri: goprotext_redirect_uri,
          scope: goprotext_scope,
          state: state
        }

        authorize_query[:audience] = goprotext_audience if goprotext_audience.present?
        authorize_uri.query = URI.encode_www_form(authorize_query)

        render json: { authorization_url: authorize_uri.to_s }
      end

      def oauth_goprotext_callback
        state = params.require(:state)
        code = params.require(:code)
        return render(json: { error: "invalid_state" }, status: :unauthorized) unless valid_oauth_state?(state)

        token_payload = exchange_oauth_code_for_token(code)
        userinfo = fetch_oauth_userinfo(token_payload.fetch("access_token"))
        oauth_companies = userinfo.fetch("companies")

        profile = userinfo["user"].is_a?(Hash) ? userinfo.fetch("user") : userinfo
        email = profile.fetch("email").to_s.downcase
        name = profile["name"].presence || email.split("@").first
        refresh_token = token_payload["refresh_token"].to_s.presence

        user = User.find_or_initialize_by(email: email)
        if user.new_record?
          company = Company.first || Company.create!(name: "GoProText")
          assign_attributes = {
            company: company,
            name: name,
            password: SecureRandom.base58(24),
            role: "customer"
          }
          assign_attributes[:goprotext_refresh_token] = refresh_token if refresh_token.present?

          user.assign_attributes(assign_attributes)
          user.save!
          company.company_memberships.find_or_create_by!(user: user) { |membership| membership.role = "member" }
        else
          update_attributes = {}
          update_attributes[:name] = name if name.present? && user.name != name
          update_attributes[:goprotext_refresh_token] = refresh_token if refresh_token.present?
          user.update!(update_attributes) if update_attributes.any?
        end

        sync_oauth_companies!(user, oauth_companies)

        company = resolve_login_company!(user)
        user.update_column(:last_login_at, Time.current)
        ImportProtextLoansJob.perform_now(company.id, user.id, token_payload.fetch("access_token"))
        app_token = token_for(user, company)

        redirect_to oauth_frontend_callback_uri(token: app_token), allow_other_host: true
      rescue KeyError => e
        Rails.logger.error("OAuth callback failed: #{e.message}, backtrace: #{e.backtrace.first(5).inspect}")
        render json: { error: "oauth_invalid_response", details: e.message }, status: :unprocessable_entity
      rescue StandardError => e
        Rails.logger.error("OAuth callback error: #{e.class}: #{e.message}")
        render json: { error: "oauth_error", details: e.message, error_class: e.class.name }, status: :unprocessable_entity
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

      def goprotext_authorize_url
        ENV.fetch("GOPROTEXT_OAUTH_AUTHORIZE_URL", "https://id.goprotext.com/oauth/authorize")
      end

      def goprotext_token_url
        ENV.fetch("GOPROTEXT_OAUTH_TOKEN_URL", "https://id.goprotext.com/oauth/token")
      end

      def goprotext_userinfo_url
        ENV.fetch("GOPROTEXT_OAUTH_USERINFO_URL", "https://id.goprotext.com/oauth/userinfo")
      end

      def goprotext_client_id
        ENV.fetch("GOPROTEXT_OAUTH_CLIENT_ID")
      end

      def goprotext_client_secret
        ENV.fetch("GOPROTEXT_OAUTH_CLIENT_SECRET")
      end

      def goprotext_redirect_uri
        ENV.fetch("GOPROTEXT_OAUTH_REDIRECT_URI", "http://localhost:3000/api/v1/auth/oauth/goprotext/callback")
      end

      def goprotext_scope
        ENV.fetch("GOPROTEXT_OAUTH_SCOPE", "openid profile email")
      end

      def goprotext_audience
        ENV["GOPROTEXT_OAUTH_AUDIENCE"]
      end

      def frontend_oauth_callback_url
        ENV.fetch("FRONTEND_OAUTH_CALLBACK_URL", "http://localhost:5173/login/oauth-callback")
      end

      def cache_oauth_state(state)
        Rails.cache.write(oauth_state_cache_key(state), true, expires_in: OAUTH_STATE_TTL)
      end

      def valid_oauth_state?(state)
        present = Rails.cache.read(oauth_state_cache_key(state))
        Rails.cache.delete(oauth_state_cache_key(state))
        present.present?
      end

      def oauth_state_cache_key(state)
        "#{OAUTH_STATE_CACHE_PREFIX}:#{state}"
      end

      def exchange_oauth_code_for_token(code)
        uri = URI(goprotext_token_url)
        request = Net::HTTP::Post.new(uri)
        request.set_form_data(
          grant_type: "authorization_code",
          code: code,
          redirect_uri: goprotext_redirect_uri,
          client_id: goprotext_client_id,
          client_secret: goprotext_client_secret
        )

        response = perform_http_request(uri, request)
        unless response.is_a?(Net::HTTPSuccess)
          Rails.logger.error("OAuth token exchange failed: #{response.code} #{response.message}\nBody: #{response.body}")
          raise KeyError, "Token exchange failed with status #{response.code}"
        end

        JSON.parse(response.body)
      end

      def fetch_oauth_userinfo(access_token)
        uri = URI(goprotext_userinfo_url)
        request = Net::HTTP::Get.new(uri)
        request["Authorization"] = "Bearer #{access_token}"

        response = perform_http_request(uri, request)
        unless response.is_a?(Net::HTTPSuccess)
          Rails.logger.error("OAuth userinfo fetch failed: #{response.code} #{response.message}\nBody: #{response.body}")
          raise KeyError, "Userinfo fetch failed with status #{response.code}"
        end

        JSON.parse(response.body)
      end

      def sync_oauth_companies!(user, oauth_companies)
        Array(oauth_companies).each do |oauth_company|
          next unless oauth_company.is_a?(Hash)

          protext_id = normalize_protext_uuid(oauth_company["id"] || oauth_company[:id])
          next if protext_id.blank?

          company_name = (oauth_company["name"] || oauth_company[:name]).to_s.strip
          company = Company.find_or_initialize_by(protext_id: protext_id)
          company.name = company_name.presence || "GoProText #{protext_id}" if company.name.blank?
          company.save! if company.new_record? || company.changed?

          user.company_memberships.find_or_create_by!(company: company) do |membership|
            membership.role = user.role == "customer" ? "member" : "admin"
          end
        end
      end

      def normalize_protext_uuid(value)
        uuid = value.to_s.strip.downcase
        return nil unless uuid.match?(/\A[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\z/)

        uuid
      end

      def perform_http_request(uri, request)
        Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == "https") do |http|
          http.request(request)
        end
      end

      def oauth_frontend_callback_uri(token:)
        uri = URI(frontend_oauth_callback_url)
        existing_params = uri.query.present? ? URI.decode_www_form(uri.query).to_h : {}
        uri.query = URI.encode_www_form(existing_params.merge("token" => token))
        uri.to_s
      end

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
        company = if requested_company_id.present?
          user.companies.find(requested_company_id)
        else
          user.companies.find_by(name: 'mysherpas') || user.company || raise(ActiveRecord::RecordNotFound)
        end

        ensure_user_membership_for_company!(user, company)
        company
      end

      def ensure_user_membership_for_company!(user, company)
        return if user.membership_for(company).present?

        role = user.role == "customer" ? "member" : "admin"
        company.company_memberships.find_or_create_by!(user: user) do |membership|
          membership.role = role
        end
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
          :custom_domain,
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
          custom_domain: permitted[:custom_domain],
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
