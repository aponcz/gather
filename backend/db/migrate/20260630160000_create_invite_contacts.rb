class CreateInviteContacts < ActiveRecord::Migration[7.1]
  def change
    create_table :invite_contacts, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.uuid :invite_id, null: false
      t.uuid :contact_id, null: false
      t.timestamps
    end

    add_index :invite_contacts, [:invite_id, :contact_id], unique: true
    add_index :invite_contacts, :contact_id
    add_foreign_key :invite_contacts, :invites
    add_foreign_key :invite_contacts, :contacts
  end
end
