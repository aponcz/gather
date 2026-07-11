class RenameInvitesToLoans < ActiveRecord::Migration[7.1]
  def change
    rename_table :invites, :loans
    rename_table :invite_contacts, :loan_contacts

    rename_column :audit_events, :invite_id, :loan_id
    rename_column :loan_contacts, :invite_id, :loan_id
    rename_column :reminders, :invite_id, :loan_id
    rename_column :request_items, :invite_id, :loan_id

    rename_index :loans, :index_invites_on_company_id, :index_loans_on_company_id if index_name_exists?(:loans, :index_invites_on_company_id)
    rename_index :loans, :index_invites_on_company_id_and_status, :index_loans_on_company_id_and_status if index_name_exists?(:loans, :index_invites_on_company_id_and_status)
    rename_index :loans, :index_invites_on_contact_id, :index_loans_on_contact_id if index_name_exists?(:loans, :index_invites_on_contact_id)
    rename_index :loans, :index_invites_on_created_by_id, :index_loans_on_created_by_id if index_name_exists?(:loans, :index_invites_on_created_by_id)
    rename_index :loans, :index_invites_on_public_token, :index_loans_on_public_token if index_name_exists?(:loans, :index_invites_on_public_token)

    rename_index :audit_events, :index_audit_events_on_invite_id, :index_audit_events_on_loan_id if index_name_exists?(:audit_events, :index_audit_events_on_invite_id)
    rename_index :loan_contacts, :index_invite_contacts_on_contact_id, :index_loan_contacts_on_contact_id if index_name_exists?(:loan_contacts, :index_invite_contacts_on_contact_id)
    rename_index :loan_contacts, :index_invite_contacts_on_invite_id_and_contact_id, :index_loan_contacts_on_loan_id_and_contact_id if index_name_exists?(:loan_contacts, :index_invite_contacts_on_invite_id_and_contact_id)
    rename_index :reminders, :index_reminders_on_invite_id, :index_reminders_on_loan_id if index_name_exists?(:reminders, :index_reminders_on_invite_id)
    rename_index :reminders, :index_reminders_on_invite_id_and_escalation_level, :index_reminders_on_loan_id_and_escalation_level if index_name_exists?(:reminders, :index_reminders_on_invite_id_and_escalation_level)
    rename_index :request_items, :index_request_items_on_invite_id, :index_request_items_on_loan_id if index_name_exists?(:request_items, :index_request_items_on_invite_id)
  end
end
