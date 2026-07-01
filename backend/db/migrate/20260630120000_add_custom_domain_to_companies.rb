class AddCustomDomainToCompanies < ActiveRecord::Migration[7.1]
  def change
    add_column :companies, :custom_domain, :string
    add_index :companies, :custom_domain, unique: true
  end
end
