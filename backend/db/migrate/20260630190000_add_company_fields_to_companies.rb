class AddCompanyFieldsToCompanies < ActiveRecord::Migration[7.1]
  def change
    add_column :organizations, :phone_number, :string unless column_exists?(:organizations, :phone_number)
    add_column :organizations, :address_line_1, :string unless column_exists?(:organizations, :address_line_1)
    add_column :organizations, :address_line_2, :string unless column_exists?(:organizations, :address_line_2)
    add_column :organizations, :city, :string unless column_exists?(:organizations, :city)
    add_column :organizations, :state, :string unless column_exists?(:organizations, :state)
    add_column :organizations, :zip_code, :string unless column_exists?(:organizations, :zip_code)
    add_column :organizations, :website, :string unless column_exists?(:organizations, :website)
    add_column :organizations, :status, :integer, default: 0, null: false unless column_exists?(:organizations, :status)
    add_column :organizations, :logo, :string unless column_exists?(:organizations, :logo)
    add_column :organizations, :trial_started_on, :date unless column_exists?(:organizations, :trial_started_on)
    add_column :organizations, :activated_on, :date unless column_exists?(:organizations, :activated_on)
    add_column :organizations, :delinquent_on, :date unless column_exists?(:organizations, :delinquent_on)
    add_column :organizations, :suspended_on, :date unless column_exists?(:organizations, :suspended_on)
  end
end