class RenameOrganizationsToCompanies < ActiveRecord::Migration[7.1]
  def up
    rename_table :organizations, :companies if table_exists?(:organizations)

    rename_index_if_exists :companies, :index_organizations_on_subdomain, :index_companies_on_subdomain

    rename_fk_column_and_indexes :users, :organization_id, :company_id,
                                 [[:index_users_on_organization_id, :index_users_on_company_id],
                                  [:index_users_on_organization_id_and_email, :index_users_on_company_id_and_email]]

    rename_fk_column_and_indexes :contacts, :organization_id, :company_id,
                                 [[:index_contacts_on_organization_id, :index_contacts_on_company_id],
                                  [:index_contacts_on_organization_id_and_email, :index_contacts_on_company_id_and_email]]

    rename_fk_column_and_indexes :invites, :organization_id, :company_id,
                                 [[:index_invites_on_organization_id, :index_invites_on_company_id],
                                  [:index_invites_on_organization_id_and_status, :index_invites_on_company_id_and_status]]

    rename_fk_column_and_indexes :audit_events, :organization_id, :company_id,
                                 [[:index_audit_events_on_organization_id, :index_audit_events_on_company_id],
                                  [:index_audit_events_on_organization_id_and_created_at, :index_audit_events_on_company_id_and_created_at]]
  end

  def down
    rename_fk_column_and_indexes :audit_events, :company_id, :organization_id,
                                 [[:index_audit_events_on_company_id, :index_audit_events_on_organization_id],
                                  [:index_audit_events_on_company_id_and_created_at, :index_audit_events_on_organization_id_and_created_at]]

    rename_fk_column_and_indexes :invites, :company_id, :organization_id,
                                 [[:index_invites_on_company_id, :index_invites_on_organization_id],
                                  [:index_invites_on_company_id_and_status, :index_invites_on_organization_id_and_status]]

    rename_fk_column_and_indexes :contacts, :company_id, :organization_id,
                                 [[:index_contacts_on_company_id, :index_contacts_on_organization_id],
                                  [:index_contacts_on_company_id_and_email, :index_contacts_on_organization_id_and_email]]

    rename_fk_column_and_indexes :users, :company_id, :organization_id,
                                 [[:index_users_on_company_id, :index_users_on_organization_id],
                                  [:index_users_on_company_id_and_email, :index_users_on_organization_id_and_email]]

    rename_index_if_exists :companies, :index_companies_on_subdomain, :index_organizations_on_subdomain

    rename_table :companies, :organizations if table_exists?(:companies)
  end

  private

  def rename_fk_column_and_indexes(table, from_column, to_column, index_renames)
    return unless table_exists?(table)

    rename_column table, from_column, to_column if column_exists?(table, from_column)
    index_renames.each do |old_name, new_name|
      rename_index_if_exists table, old_name, new_name
    end
  end

  def rename_index_if_exists(table, old_name, new_name)
    return unless index_name_exists?(table, old_name)
    return if index_name_exists?(table, new_name)

    rename_index table, old_name, new_name
  end
end
