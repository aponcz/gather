class AddProtextIdToCompanies < ActiveRecord::Migration[7.1]
  def change
    add_column :companies, :protext_id, :uuid
    add_index :companies, :protext_id, unique: true
  end
end