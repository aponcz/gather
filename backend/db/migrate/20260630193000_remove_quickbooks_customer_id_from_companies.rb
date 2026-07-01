class RemoveQuickbooksCustomerIdFromCompanies < ActiveRecord::Migration[7.1]
  def change
    remove_column :organizations, :quickbooks_customer_id, :string if column_exists?(:organizations, :quickbooks_customer_id)
  end
end