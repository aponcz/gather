class CreateCompanyMemberships < ActiveRecord::Migration[7.1]
  def up
    create_table :company_memberships, id: :uuid do |t|
      t.references :company, type: :uuid, null: false, foreign_key: true
      t.references :user, type: :uuid, null: false, foreign_key: true
      t.string :role, null: false, default: "member"

      t.timestamps
    end

    add_index :company_memberships, %i[company_id user_id], unique: true

    execute <<~SQL
      INSERT INTO company_memberships (company_id, user_id, role, created_at, updated_at)
      SELECT users.company_id, users.id, COALESCE(users.role, 'member'), NOW(), NOW()
      FROM users
      WHERE users.company_id IS NOT NULL
      ON CONFLICT (company_id, user_id) DO NOTHING;
    SQL
  end

  def down
    drop_table :company_memberships
  end
end
