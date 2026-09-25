class CreateCompanySignInCodes < ActiveRecord::Migration[7.1]
  def change
    create_table :company_sign_in_codes do |t|
      t.string :digest, null: false
      t.references :user, type: :uuid, null: false, foreign_key: { on_delete: :cascade }
      t.references :company, type: :uuid, null: false, foreign_key: { on_delete: :cascade }
      t.datetime :expires_at, null: false
    end
    add_index :company_sign_in_codes, :digest, unique: true
    add_index :company_sign_in_codes, :expires_at
  end
end
