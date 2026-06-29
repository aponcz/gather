module Api
  module V1
    class AuthController < ApplicationController
      before_action :authenticate_user!, only: :me

      def register
        org = Organization.create!(name: params.require(:organization_name))
        user = org.users.create!(
          name: params.require(:name),
          email: params.require(:email).downcase,
          password: params.require(:password),
          role: :admin
        )
        render json: { token: token_for(user), user: user_payload(user), organization: org }, status: :created
      end

      def login
        user = User.find_by!(email: params.require(:email).downcase)
        return render(json: { error: "invalid_credentials" }, status: :unauthorized) unless user.authenticate(params.require(:password))

        render json: { token: token_for(user), user: user_payload(user), organization: user.organization }
      end

      def me
        render json: { user: user_payload(current_user), organization: current_organization }
      end

      private

      def token_for(user)
        JwtService.encode({ sub: user.id, organization_id: user.organization_id, type: "user" })
      end

      def user_payload(user)
        user.as_json(only: %i[id name email role organization_id])
      end
    end
  end
end
