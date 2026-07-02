module Api
  module V1
    class UsersController < ApplicationController
      before_action :authenticate_user!
      before_action :authorize_admin_or_god!, only: %i[index update]

      def index
        users = User.order(:name)
        render json: users, only: %i[id name email role]
      end

      def update
        user = User.find(params[:id])
        role = params[:role]
        if role.present? && user.update(role: role)
          render json: user, only: %i[id name email role]
        else
          render json: { errors: user.errors.full_messages }, status: :unprocessable_entity
        end
      end

      private

      def authorize_admin_or_god!
        return if current_user.god? || current_user.admin?

        render json: { error: 'Unauthorized' }, status: :forbidden
      end
    end
  end
end
