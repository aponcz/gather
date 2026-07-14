module Api
  module V1
    class LoansController < ApplicationController
      require "zip"

      before_action :authenticate_user!

      def index
        loans = current_company.loans.includes(:contact, :loan_contacts, { request_items: :uploaded_files }).order(created_at: :desc)
        render json: loans.map { |record| loan_payload(record) }
      end

      def show
        render json: loan_payload(loan, include_audit_events: true)
      end

      def create
        recipients, missing_contact_ids = recipients_from_params
        if missing_contact_ids.any?
          return render json: { error: "contacts_not_found", contact_ids: missing_contact_ids }, status: :unprocessable_entity
        end
        if recipients.empty?
          return render json: { error: "recipients_required" }, status: :unprocessable_entity
        end

        loan = Loan.transaction do
          created_loan = current_company.loans.create!(
            loan_params.merge(
              contact: recipients.first[:contact],
              created_by: current_user
            )
          )
          create_request_items!(created_loan)
          create_loan_recipients!(created_loan, recipients)
          created_loan
        end

        AuditLogger.log!(company: current_company, loan: loan, user: current_user, action: "loan.created")
        render json: loan_payload(loan), status: :created
      end

      def bulk_create
        recipients, missing_contact_ids = recipients_from_params
        if missing_contact_ids.any?
          return render json: { error: "contacts_not_found", contact_ids: missing_contact_ids }, status: :unprocessable_entity
        end
        if recipients.empty?
          return render json: { error: "recipients_required" }, status: :unprocessable_entity
        end

        created_loan = Loan.transaction do
          loan = current_company.loans.create!(loan_params.merge(contact: recipients.first[:contact], created_by: current_user))
          create_request_items!(loan)

          added_recipients = create_loan_recipients!(loan, recipients)

          loan.sent! unless loan.sent?
          added_recipients.each do |loan_contact|
            SendLoanInviteJob.perform_later(loan.id, nil, loan_contact.id)
          end
          AuditLogger.log!(company: current_company, loan: loan, user: current_user, action: "loan.created", metadata: { bulk_contact_count: added_recipients.length })
          loan
        end

        recipient_count = created_loan.loan_contacts.count

        render json: {
          loan: loan_payload(created_loan),
          contact_count: recipient_count,
          message: "Loan created and sent to #{recipient_count} contacts"
        }, status: :created
      end

      def import_loans
        result = ProtextLoansImportService.new(company: current_company, user: current_user).call
        render json: result, status: :created
      rescue ProtextLoansImportService::Error => e
        Rails.logger.error("ProText loans import failed: #{e.message}")
        render json: { error: "protext_sync_failed", details: e.message }, status: :bad_gateway
      end

      def update
        update_recipients = params.key?(:contact_ids) || params.key?(:recipients)
        if update_recipients
          recipients, missing_contact_ids = recipients_from_params
          if missing_contact_ids.any?
            return render json: { error: "contacts_not_found", contact_ids: missing_contact_ids }, status: :unprocessable_entity
          end
          if recipients.empty?
            return render json: { error: "recipients_required" }, status: :unprocessable_entity
          end
        end

        Loan.transaction do
          loan.update!(loan_params)

          if update_recipients
            loan.loan_contacts.destroy_all
            create_loan_recipients!(loan, recipients)
            loan.update!(contact: recipients.first[:contact])
          end

          update_request_items! if params.key?(:request_items)
        end

        AuditLogger.log!(company: current_company, loan: loan, user: current_user, action: "loan.updated")
        render json: loan_payload(loan.reload)
      end

      def add_contacts
        recipients, missing_contact_ids = recipients_from_params
        if missing_contact_ids.any?
          return render json: { error: "contacts_not_found", contact_ids: missing_contact_ids }, status: :unprocessable_entity
        end
        if recipients.empty?
          return render json: { error: "recipients_required" }, status: :unprocessable_entity
        end

        added_recipients = []

        Loan.transaction do
          recipients.each do |recipient|
            if loan.loan_contacts.where("LOWER(email) = ?", recipient[:email].downcase).exists?
              next
            end

            loan_contact = loan.loan_contacts.create!(
              contact: recipient[:contact],
              name: recipient[:name],
              email: recipient[:email],
              phone: recipient[:phone]
            )
            added_recipients << loan_contact
          end

          added_recipients.each do |loan_contact|
            SendLoanInviteJob.perform_later(loan.id, nil, loan_contact.id)
          end

          AuditLogger.log!(
            company: current_company,
            loan: loan,
            user: current_user,
            action: "loan.contacts_added",
            metadata: { added_contact_count: added_recipients.length }
          )
        end

        render json: {
          loan: loan_payload(loan.reload),
          added_contact_count: added_recipients.length
        }
      end

      def send_loan
        loan.sent! unless loan.sent?
        if loan.loan_contacts.exists?
          loan.loan_contacts.find_each do |recipient|
            SendLoanInviteJob.perform_later(loan.id, nil, recipient.id)
          end
        else
          SendLoanInviteJob.perform_later(loan.id)
        end
        render json: { status: "queued", loan: loan }
      end

      def cancel
        loan.cancelled!
        AuditLogger.log!(company: current_company, loan: loan, user: current_user, action: "loan.cancelled")
        render json: loan
      end

      def download_all_files
        request_items_with_files = loan.request_items.includes(:uploaded_files)
        storage_service = StorageService.new
        used_names = Hash.new(0)

        zip_data = Zip::OutputStream.write_buffer do |zip|
          request_items_with_files.each do |request_item|
            section_name = (request_item.section_name.presence || "Requested items").strip

            request_item.uploaded_files.each do |uploaded_file|
              filename = uploaded_file.filename.presence || "file-#{uploaded_file.id}"
              ext = File.extname(filename)
              basename = File.basename(filename, ext)
              key = "#{section_name}/#{filename}"
              used_names[key] += 1
              entry_name = used_names[key] > 1 ? "#{section_name}/#{basename}-#{used_names[key]}#{ext}" : "#{section_name}/#{filename}"

              zip.put_next_entry(entry_name)
              zip.write(storage_service.download(key: uploaded_file.storage_key))
            end
          end
        end

        zip_data.rewind
        archive_name = "#{loan.title.to_s.parameterize.presence || 'document-collection'}-files.zip"
        send_data zip_data.read, type: "application/zip", disposition: "attachment", filename: archive_name
      end

      private

      def loan
        @loan ||= current_company.loans.find(params[:id])
      end

      def loan_params
        params.permit(:title, :message, :due_at, :brand_color, :logo_url, :loan_amount_in_cents, :loan_type)
      end

      def create_request_items!(loan)
        Array(params[:request_items]).each do |item|
          loan.request_items.create!(item.permit(:title, :description, :kind, :due_at, :required, :section_name))
        end
      end

      def update_request_items!
        retained_ids = []

        Array(params[:request_items]).each do |item|
          attributes = item.permit(:title, :description, :kind, :due_at, :required, :section_name)
          if item[:id].present?
            request_item = loan.request_items.find(item[:id])
            request_item.update!(attributes)
            retained_ids << request_item.id
          else
            retained_ids << loan.request_items.create!(attributes).id
          end
        end

        loan.request_items.where.not(id: retained_ids).destroy_all
      end

      def recipients_from_params
        recipients = []
        missing_contact_ids = []

        contact_ids = Array(params[:contact_ids]).map(&:to_s).reject(&:blank?).uniq
        if contact_ids.any?
          contacts = current_company.contacts.where(id: contact_ids).index_by { |contact| contact.id.to_s }
          missing_contact_ids = contact_ids - contacts.keys

          (contact_ids - missing_contact_ids).each do |contact_id|
            contact = contacts.fetch(contact_id)
            recipients << {
              contact: contact,
              name: contact.name,
              email: contact.email,
              phone: contact.phone
            }
          end
        end

        payload_recipients = Array(params[:recipients])
        payload_recipients.each do |recipient|
          recipient_hash = if recipient.respond_to?(:to_unsafe_h)
            recipient.to_unsafe_h
          elsif recipient.respond_to?(:to_h)
            recipient.to_h
          else
            {}
          end

          email = (recipient_hash["email"] || recipient_hash[:email]).to_s.strip.downcase
          next if email.blank?

          name = (recipient_hash["name"] || recipient_hash[:name]).to_s.strip
          phone = (recipient_hash["phone"] || recipient_hash[:phone]).to_s.strip
          recipients << {
            contact: nil,
            name: name.presence || email.split("@").first,
            email: email,
            phone: phone.presence
          }
        end

        recipients = recipients.uniq { |recipient| recipient[:email].downcase }
        [recipients, missing_contact_ids]
      end

      def create_loan_recipients!(loan, recipients)
        recipients.map do |recipient|
          loan.loan_contacts.create!(
            contact: recipient[:contact],
            name: recipient[:name],
            email: recipient[:email],
            phone: recipient[:phone]
          )
        end
      end

      def loan_payload(record, include_audit_events: false)
        payload = record.as_json(
          include: {
            contact: {},
            request_items: {
              include: :uploaded_files
            }
          }
        )
        payload["contacts"] = record.recipient_contacts
        if include_audit_events
          payload["audit_events"] = record.audit_events.order(created_at: :desc).map { |audit_event| audit_event.as_json(methods: :actor_email) }
        end
        payload
      end
    end
  end
end
