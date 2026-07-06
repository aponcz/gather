class AddProtextIdToInvites < ActiveRecord::Migration[7.1]
  def change
    add_column :invites, :protext_id, :uuid
  end
end