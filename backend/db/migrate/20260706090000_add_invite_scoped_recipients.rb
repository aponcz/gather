class AddInviteScopedRecipients < ActiveRecord::Migration[7.1]
  def change
    add_column :invite_contacts, :name, :string
    add_column :invite_contacts, :email, :string
    add_column :invite_contacts, :phone, :string

    change_column_null :invite_contacts, :contact_id, true
    change_column_null :invites, :contact_id, true
  end
end
