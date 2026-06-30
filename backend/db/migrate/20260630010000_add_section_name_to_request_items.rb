class AddSectionNameToRequestItems < ActiveRecord::Migration[7.1]
  def change
    add_column :request_items, :section_name, :string
  end
end