class CreateGatherSchema < ActiveRecord::Migration[7.1]
  def change
    enable_extension "pgcrypto" unless extension_enabled?("pgcrypto")

    create_table :organizations, id: :uuid do |t|
      t.string :name, null: false
      t.string :subdomain
      t.string :brand_color
      t.string :logo_url
      t.timestamps
    end
    add_index :organizations, :subdomain, unique: true

    create_table :users, id: :uuid do |t|
      t.references :organization, type: :uuid, null: false, foreign_key: true
      t.string :name, null: false
      t.string :email, null: false
      t.string :password_digest, null: false
      t.string :role, null: false, default: "member"
      t.datetime :last_login_at
      t.timestamps
    end
    add_index :users, [:organization_id, :email], unique: true

    create_table :contacts, id: :uuid do |t|
      t.references :organization, type: :uuid, null: false, foreign_key: true
      t.string :name, null: false
      t.string :email, null: false
      t.string :phone
      t.string :external_id
      t.timestamps
    end
    add_index :contacts, [:organization_id, :email], unique: true

    create_table :invites, id: :uuid do |t|
      t.references :organization, type: :uuid, null: false, foreign_key: true
      t.references :contact, type: :uuid, null: false, foreign_key: true
      t.references :created_by, type: :uuid, null: false, foreign_key: { to_table: :users }
      t.string :title, null: false
      t.text :message
      t.string :status, null: false, default: "draft"
      t.string :public_token, null: false
      t.datetime :due_at
      t.string :brand_color
      t.string :logo_url
      t.timestamps
    end
    add_index :invites, :public_token, unique: true
    add_index :invites, [:organization_id, :status]

    create_table :request_items, id: :uuid do |t|
      t.references :invite, type: :uuid, null: false, foreign_key: true
      t.string :title, null: false
      t.text :description
      t.string :kind, null: false, default: "document"
      t.string :status, null: false, default: "pending"
      t.boolean :required, null: false, default: true
      t.datetime :due_at
      t.jsonb :form_schema, null: false, default: {}
      t.jsonb :form_response, null: false, default: {}
      t.timestamps
    end

    create_table :uploaded_files, id: :uuid do |t|
      t.references :request_item, type: :uuid, null: false, foreign_key: true
      t.references :uploaded_by_contact, type: :uuid, foreign_key: { to_table: :contacts }
      t.references :reviewed_by, type: :uuid, foreign_key: { to_table: :users }
      t.string :storage_key, null: false
      t.string :filename, null: false
      t.string :content_type, null: false
      t.bigint :byte_size
      t.string :status, null: false, default: "uploaded"
      t.text :rejection_reason
      t.datetime :reviewed_at
      t.timestamps
    end
    add_index :uploaded_files, :storage_key, unique: true

    create_table :audit_events, id: :uuid do |t|
      t.references :organization, type: :uuid, null: false, foreign_key: true
      t.references :invite, type: :uuid, foreign_key: true
      t.references :user, type: :uuid, foreign_key: true
      t.references :contact, type: :uuid, foreign_key: true
      t.string :action, null: false
      t.string :ip_address
      t.string :user_agent
      t.jsonb :metadata, null: false, default: {}
      t.timestamps
    end
    add_index :audit_events, [:organization_id, :created_at]

    create_table :reminders, id: :uuid do |t|
      t.references :invite, type: :uuid, null: false, foreign_key: true
      t.string :channel, null: false, default: "email"
      t.string :status, null: false, default: "scheduled"
      t.datetime :send_at, null: false
      t.datetime :sent_at
      t.text :error_message
      t.timestamps
    end
    add_index :reminders, [:status, :send_at]
  end
end
