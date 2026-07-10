class AddProtextRefreshTokenColumn < ActiveRecord::Migration[7.1]
  def change
    add_column :users, :goprotext_refresh_token, :string
  end
end
