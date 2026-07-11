module Api
  module V1
    class UploadedFilesController < ApplicationController
      before_action :authenticate_user!

      def show
        render json: uploaded_file
      end

      def approve
        uploaded_file.update!(status: :approved, reviewed_by: current_user, reviewed_at: Time.current)
        uploaded_file.request_item.approved!
        uploaded_file.request_item.loan.refresh_status!
        AuditLogger.log!(company: current_company, loan: uploaded_file.request_item.loan, user: current_user, action: "file.approved", metadata: { uploaded_file_id: uploaded_file.id, filename: uploaded_file.filename })
        render json: uploaded_file
      end

      def reject
        uploaded_file.update!(status: :rejected, reviewed_by: current_user, reviewed_at: Time.current, rejection_reason: params[:reason])
        uploaded_file.request_item.rejected!
        AuditLogger.log!(company: current_company, loan: uploaded_file.request_item.loan, user: current_user, action: "file.rejected", metadata: { uploaded_file_id: uploaded_file.id, filename: uploaded_file.filename, reason: params[:reason] })
        render json: uploaded_file
      end

      def download_url
        render json: { url: StorageService.new.presigned_download_url(key: uploaded_file.storage_key) }
      end

      private

      def uploaded_file
        @uploaded_file ||= current_company.uploaded_files.find(params[:id])
      end
    end
  end
end
