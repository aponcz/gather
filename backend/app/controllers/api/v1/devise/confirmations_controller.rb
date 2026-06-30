module Api
  module V1
    module Devise
      class ConfirmationsController < BaseController
        def create
          user = User.find_by(email: confirmation_params.fetch(:email).downcase)
          user&.send_confirmation_instructions

          render json: { message: "If your account exists, confirmation instructions have been sent." }
        end

        def show
          user = User.confirm_by_token(params.require(:confirmation_token))

          if user.errors.empty?
            render json: { message: "Email confirmed successfully" }
          else
            render json: { error: "validation_failed", details: user.errors.full_messages }, status: :unprocessable_entity
          end
        end

        private

        def confirmation_params
          params.require(:user).permit(:email)
        end
      end
    end
  end
end
