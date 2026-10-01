module Api
  module V1
    module Client
      class PortalController < ApplicationController
        before_action :authenticate_client!, except: %i[request_magic_link create_session]

        def request_magic_link
          contact = Contact.find_by!(email: params.require(:email).downcase)
          token = JwtService.encode({ contact_id: contact.id, company_id: contact.company_id, type: "client_magic" }, expires_in: 20.minutes)
          # In production, email this token as a link instead of returning it.
          render json: { magic_token: token }
        end

        def create_session
          payload = JwtService.decode(params.require(:magic_token))
          return render(json: { error: "wrong_token_type" }, status: :unauthorized) unless payload["type"] == "client_magic"

          identity, recipient = client_identity_from(payload)
          session_token = JwtService.encode(identity.merge(type: "client"), expires_in: 7.days)
          render json: { token: session_token, contact: recipient }
        rescue JWT::DecodeError, ActiveRecord::RecordNotFound, KeyError
          render json: { error: "invalid_magic_token" }, status: :unauthorized
        end

        def show_loan
          loan = find_accessible_loan(params[:id])
          loan.viewed! if loan.sent?
          AuditLogger.log!(company: loan.company, loan: loan, contact: @current_contact, action: "loan.viewed", metadata: { ip_address: request.remote_ip, user_agent: request.user_agent })
          render json: loan.as_json(include: { contact: {}, contacts: {}, request_items: { include: :uploaded_files } })
        end

        def create_upload_url
          loan = find_accessible_loan_by_request_item(params[:id])
          item = loan.request_items.find(params[:id])
          key = "company-#{item.company.id}/loan-#{item.loan.id}/request-#{item.id}/#{SecureRandom.uuid}-#{params.require(:filename)}"
          url = StorageService.new.presigned_upload_url(key: key)
          render json: { upload_url: url, storage_key: key }
        end

        def complete_upload
          loan = find_accessible_loan_by_request_item(params[:id])
          item = loan.request_items.find(params[:id])
          file = item.uploaded_files.create!(
            uploaded_by_contact: @current_contact,
            storage_key: params.require(:storage_key),
            filename: params.require(:filename),
            content_type: params.require(:content_type),
            byte_size: params[:byte_size]
          )
          AuditLogger.log!(company: item.company, loan: item.loan, contact: @current_contact, action: "file.uploaded", metadata: { uploaded_file_id: file.id, filename: file.filename })
          render json: file, status: :created
        end

        def download_url
          render json: { url: StorageService.new.presigned_download_url(key: uploaded_file.storage_key) }
        end

        private

        def client_identity_from(payload)
          if payload["contact_id"].present?
            contact = Contact.find(payload["contact_id"])
            [{ contact_id: contact.id, company_id: contact.company_id }, contact]
          elsif payload["loan_contact_id"].present?
            loan_contact = LoanContact.includes(:loan).find(payload["loan_contact_id"])
            [
              { loan_contact_id: loan_contact.id, company_id: loan_contact.loan.company_id },
              loan_contact.recipient_payload
            ]
          else
            raise KeyError, "client identity missing"
          end
        end

        def find_accessible_loan(public_token)
          if @current_loan_contact.present?
            return @current_loan_contact.loan if @current_loan_contact.loan.public_token == public_token

            raise ActiveRecord::RecordNotFound
          end

          # Support both old single-contact loans and new shared loans
          Loan.where(public_token: public_token)
            .where(
              'contact_id = :contact_id OR id IN (SELECT loan_id FROM loan_contacts WHERE contact_id = :contact_id OR LOWER(email) = :email)',
              contact_id: @current_client_contact_id,
              email: @current_client_email
            )
            .first! || raise(ActiveRecord::RecordNotFound)
        end

        def find_accessible_loan_by_request_item(request_item_id)
          if @current_loan_contact.present?
            return @current_loan_contact.loan.request_items.find(request_item_id).loan
          end

          # Support both old single-contact and new shared loans for request items
          RequestItem.where(id: request_item_id)
            .joins(:loan)
            .where(
              'loans.contact_id = :contact_id OR loans.id IN (SELECT loan_id FROM loan_contacts WHERE contact_id = :contact_id OR LOWER(email) = :email)',
              contact_id: @current_client_contact_id,
              email: @current_client_email
            )
            .first!&.loan || raise(ActiveRecord::RecordNotFound)
        end

        def uploaded_file
          if @current_loan_contact.present?
            return @uploaded_file ||= UploadedFile.joins(:request_item)
              .where(id: params[:id], request_items: { loan_id: @current_loan_contact.loan_id })
              .first!
          end

          @uploaded_file ||= UploadedFile.joins(request_item: :loan)
            .where(id: params[:id])
            .where(
              'loans.contact_id = :contact_id OR loans.id IN (SELECT loan_id FROM loan_contacts WHERE contact_id = :contact_id OR LOWER(email) = :email)',
              contact_id: @current_client_contact_id,
              email: @current_client_email
            )
            .first! || raise(ActiveRecord::RecordNotFound)
        end
      end
    end
  end
end
