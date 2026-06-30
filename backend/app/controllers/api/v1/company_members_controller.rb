module Api
  module V1
    class CompanyMembersController < ApplicationController
      before_action :authenticate_user!
      before_action :authorize_admin!

      def index
        memberships = current_company.company_memberships.includes(:user).order(created_at: :desc)
        render json: memberships.map { |membership| member_payload(membership.user, membership) }
      end

      def create
        email = member_params.fetch(:email).downcase
        member = User.find_by(email: email)
        existing_user = member.present?
        generated_password = nil

        if member.nil?
          generated_password = SecureRandom.base58(14)
          member = User.create!(
            company: current_company,
            name: member_params.fetch(:name),
            email: email,
            role: role_param,
            password: generated_password
          )
        end

        membership = current_company.company_memberships.find_or_initialize_by(user: member)
        return render(json: { error: "already_member" }, status: :unprocessable_entity) if membership.persisted? && existing_user

        membership.role = role_param
        membership.save! if membership.new_record? || membership.changed?

        if member.company_id.blank? || member.company_id == current_company.id
          member.update!(company: current_company, role: role_param)
        end

        SendMemberInviteJob.perform_later(member.id, current_company.id, generated_password)
        AuditLogger.log!(
          company: current_company,
          user: current_user,
          action: "company.member_invited",
          metadata: {
            invited_email: member.email,
            role: membership.role
          }
        )

        render json: member_payload(member, membership), status: :created
      end

      def update
        membership = current_company.company_memberships.find_by!(user_id: params[:id])
        member = membership.user
        membership.update!(role: role_param)
        member.update!(role: role_param) if member.company_id == current_company.id

        AuditLogger.log!(
          company: current_company,
          user: current_user,
          action: "company.member_role_updated",
          metadata: {
            member_email: member.email,
            role: membership.role
          }
        )

        render json: member_payload(member, membership)
      end

      private

      def authorize_admin!
        return if current_membership&.admin? || current_membership&.owner?

        render json: { error: "forbidden" }, status: :forbidden
      end

      def invite_params
        params.permit(:role)
      end

      def member_params
        params.permit(:name, :email, :role)
      end

      def role_param
        role = member_params[:role].presence || "member"
        return role if %w[owner admin member].include?(role)

        raise ActiveRecord::RecordInvalid.new(CompanyMembership.new.tap { |membership| membership.errors.add(:role, "is not included in the list") })
      end

      def member_payload(member, membership)
        member.as_json(only: %i[id name email created_at]).merge(
          "role" => membership.role,
          "invitation_status" => member.last_login_at.present? ? "accepted" : "pending"
        )
      end
    end
  end
end
