class AddDeviseFieldsToUsers < ActiveRecord::Migration[7.1]
  def up
    change_table :users, bulk: true do |t|
      t.string :encrypted_password, null: false, default: "" unless column_exists?(:users, :encrypted_password)

      t.string :reset_password_token unless column_exists?(:users, :reset_password_token)
      t.datetime :reset_password_sent_at unless column_exists?(:users, :reset_password_sent_at)

      t.datetime :remember_created_at unless column_exists?(:users, :remember_created_at)

      t.integer :sign_in_count, null: false, default: 0 unless column_exists?(:users, :sign_in_count)
      t.datetime :current_sign_in_at unless column_exists?(:users, :current_sign_in_at)
      t.datetime :last_sign_in_at unless column_exists?(:users, :last_sign_in_at)
      t.string :current_sign_in_ip unless column_exists?(:users, :current_sign_in_ip)
      t.string :last_sign_in_ip unless column_exists?(:users, :last_sign_in_ip)

      t.integer :failed_attempts, null: false, default: 0 unless column_exists?(:users, :failed_attempts)
      t.string :unlock_token unless column_exists?(:users, :unlock_token)
      t.datetime :locked_at unless column_exists?(:users, :locked_at)

      t.string :confirmation_token unless column_exists?(:users, :confirmation_token)
      t.datetime :confirmed_at unless column_exists?(:users, :confirmed_at)
      t.datetime :confirmation_sent_at unless column_exists?(:users, :confirmation_sent_at)
      t.string :unconfirmed_email unless column_exists?(:users, :unconfirmed_email)

      t.integer :password_archived_count, default: 0 unless column_exists?(:users, :password_archived_count)
      t.datetime :password_changed_at unless column_exists?(:users, :password_changed_at)
      t.boolean :allow_password_change, default: false unless column_exists?(:users, :allow_password_change)
    end

    add_index :users, :reset_password_token, unique: true unless index_exists?(:users, :reset_password_token)
    add_index :users, :unlock_token, unique: true unless index_exists?(:users, :unlock_token)
    add_index :users, :confirmation_token, unique: true unless index_exists?(:users, :confirmation_token)

    return if table_exists?(:old_passwords)

    create_table :old_passwords, id: :uuid do |t|
      t.string :encrypted_password, null: false, default: ""
      t.string :password_archivable_type, null: false
      t.uuid :password_archivable_id, null: false
      t.datetime :created_at
    end

    add_index :old_passwords, %i[password_archivable_type password_archivable_id], name: :index_password_archivable
  end

  def down
    remove_index :users, :confirmation_token if index_exists?(:users, :confirmation_token)
    remove_index :users, :unlock_token if index_exists?(:users, :unlock_token)
    remove_index :users, :reset_password_token if index_exists?(:users, :reset_password_token)

    remove_column :users, :allow_password_change if column_exists?(:users, :allow_password_change)
    remove_column :users, :password_changed_at if column_exists?(:users, :password_changed_at)
    remove_column :users, :password_archived_count if column_exists?(:users, :password_archived_count)

    remove_column :users, :unconfirmed_email if column_exists?(:users, :unconfirmed_email)
    remove_column :users, :confirmation_sent_at if column_exists?(:users, :confirmation_sent_at)
    remove_column :users, :confirmed_at if column_exists?(:users, :confirmed_at)
    remove_column :users, :confirmation_token if column_exists?(:users, :confirmation_token)

    remove_column :users, :locked_at if column_exists?(:users, :locked_at)
    remove_column :users, :unlock_token if column_exists?(:users, :unlock_token)
    remove_column :users, :failed_attempts if column_exists?(:users, :failed_attempts)

    remove_column :users, :last_sign_in_ip if column_exists?(:users, :last_sign_in_ip)
    remove_column :users, :current_sign_in_ip if column_exists?(:users, :current_sign_in_ip)
    remove_column :users, :last_sign_in_at if column_exists?(:users, :last_sign_in_at)
    remove_column :users, :current_sign_in_at if column_exists?(:users, :current_sign_in_at)
    remove_column :users, :sign_in_count if column_exists?(:users, :sign_in_count)

    remove_column :users, :remember_created_at if column_exists?(:users, :remember_created_at)

    remove_column :users, :reset_password_sent_at if column_exists?(:users, :reset_password_sent_at)
    remove_column :users, :reset_password_token if column_exists?(:users, :reset_password_token)

    remove_column :users, :encrypted_password if column_exists?(:users, :encrypted_password)

    drop_table :old_passwords if table_exists?(:old_passwords)
  end
end
