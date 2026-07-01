class UpdateUserRolesToGodAdminCustomer < ActiveRecord::Migration[7.1]
  def up
    execute <<~SQL
      UPDATE users
      SET role = CASE role
        WHEN 'owner' THEN 'god'
        WHEN 'member' THEN 'customer'
        WHEN 'admin' THEN 'admin'
        ELSE 'customer'
      END
    SQL

    change_column_default :users, :role, from: 'member', to: 'customer'
  end

  def down
    execute <<~SQL
      UPDATE users
      SET role = CASE role
        WHEN 'god' THEN 'owner'
        WHEN 'customer' THEN 'member'
        WHEN 'admin' THEN 'admin'
        ELSE 'member'
      END
    SQL

    change_column_default :users, :role, from: 'customer', to: 'member'
  end
end
