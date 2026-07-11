class AddLoanFieldsToLoans < ActiveRecord::Migration[7.1]
  def change
    add_column :loans, :loan_amount_in_cents, :integer
    add_column :loans, :loan_type, :string
  end
end
