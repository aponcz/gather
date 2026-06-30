class AddSectionNameToRequestItems < ActiveRecord::Migration[7.1]
  def change
    add_column :request_items, :section_name, :string unless column_exists?(:request_items, :section_name)
  end
end