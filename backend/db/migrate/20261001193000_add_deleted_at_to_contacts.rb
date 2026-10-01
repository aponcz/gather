class AddDeletedAtToContacts < ActiveRecord::Migration[8.0]
  def change
    add_column :contacts, :deleted_at, :datetime
    add_index :contacts, :deleted_at

    remove_index :contacts, column: %i[company_id email]
    add_index :contacts, %i[company_id email], unique: true, where: "deleted_at IS NULL"
  end
end
