module Api
  module V1
    module Devise
      class RecoveriesController < BaseController
        def create
          user = User.find_by(email: recovery_create_params.fetch(:email).downcase)
          user&.send_reset_password_instructions

          render json: { message: "If an account exists with that email, reset instructions have been sent." }
        end

        def update
          user = User.reset_password_by_token(recovery_update_params)

          if user.errors.empty?
            render json: { message: "Password reset successful" }
          else
            render json: { error: "validation_failed", details: user.errors.full_messages }, status: :unprocessable_entity
          end
        end

        private

        def recovery_create_params
          params.require(:user).permit(:email)
        end

        def recovery_update_params
          params.require(:user).permit(:reset_password_token, :password, :password_confirmation)
        end
      end
    end
  end
end
