# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[7.1].define(version: 2026_06_30_220000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pgcrypto"
  enable_extension "plpgsql"

  create_table "audit_events", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "company_id", null: false
    t.uuid "invite_id"
    t.uuid "user_id"
    t.uuid "contact_id"
    t.string "action", null: false
    t.string "ip_address"
    t.string "user_agent"
    t.jsonb "metadata", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["company_id", "created_at"], name: "index_audit_events_on_company_id_and_created_at"
    t.index ["company_id"], name: "index_audit_events_on_company_id"
    t.index ["contact_id"], name: "index_audit_events_on_contact_id"
    t.index ["invite_id"], name: "index_audit_events_on_invite_id"
    t.index ["user_id"], name: "index_audit_events_on_user_id"
  end

  create_table "companies", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "name", null: false
    t.string "subdomain"
    t.string "brand_color"
    t.string "logo_url"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "phone_number"
    t.string "address_line_1"
    t.string "address_line_2"
    t.string "city"
    t.string "state"
    t.string "zip_code"
    t.string "website"
    t.integer "status", default: 0, null: false
    t.string "logo"
    t.date "trial_started_on"
    t.date "activated_on"
    t.date "delinquent_on"
    t.date "suspended_on"
    t.string "custom_domain"
    t.index ["custom_domain"], name: "index_companies_on_custom_domain", unique: true
    t.index ["subdomain"], name: "index_companies_on_subdomain", unique: true
  end

  create_table "company_memberships", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "company_id", null: false
    t.uuid "user_id", null: false
    t.string "role", default: "member", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["company_id", "user_id"], name: "index_company_memberships_on_company_id_and_user_id", unique: true
    t.index ["company_id"], name: "index_company_memberships_on_company_id"
    t.index ["user_id"], name: "index_company_memberships_on_user_id"
  end

  create_table "contacts", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "company_id", null: false
    t.string "name", null: false
    t.string "email", null: false
    t.string "phone"
    t.string "external_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["company_id", "email"], name: "index_contacts_on_company_id_and_email", unique: true
    t.index ["company_id"], name: "index_contacts_on_company_id"
  end

  create_table "invite_contacts", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "invite_id", null: false
    t.uuid "contact_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["contact_id"], name: "index_invite_contacts_on_contact_id"
    t.index ["invite_id", "contact_id"], name: "index_invite_contacts_on_invite_id_and_contact_id", unique: true
  end

  create_table "invites", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "company_id", null: false
    t.uuid "contact_id", null: false
    t.uuid "created_by_id", null: false
    t.string "title", null: false
    t.text "message"
    t.string "status", default: "draft", null: false
    t.string "public_token", null: false
    t.datetime "due_at"
    t.string "brand_color"
    t.string "logo_url"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["company_id", "status"], name: "index_invites_on_company_id_and_status"
    t.index ["company_id"], name: "index_invites_on_company_id"
    t.index ["contact_id"], name: "index_invites_on_contact_id"
    t.index ["created_by_id"], name: "index_invites_on_created_by_id"
    t.index ["public_token"], name: "index_invites_on_public_token", unique: true
  end

  create_table "old_passwords", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "encrypted_password", default: "", null: false
    t.string "password_archivable_type", null: false
    t.uuid "password_archivable_id", null: false
    t.datetime "created_at"
    t.index ["password_archivable_type", "password_archivable_id"], name: "index_password_archivable"
  end

  create_table "reminders", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "invite_id", null: false
    t.string "channel", default: "email", null: false
    t.string "status", default: "scheduled", null: false
    t.datetime "send_at", null: false
    t.datetime "sent_at"
    t.text "error_message"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["invite_id"], name: "index_reminders_on_invite_id"
    t.index ["status", "send_at"], name: "index_reminders_on_status_and_send_at"
  end

  create_table "request_items", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "invite_id", null: false
    t.string "title", null: false
    t.text "description"
    t.string "kind", default: "document", null: false
    t.string "status", default: "pending", null: false
    t.boolean "required", default: true, null: false
    t.datetime "due_at"
    t.jsonb "form_schema", default: {}, null: false
    t.jsonb "form_response", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "section_name"
    t.index ["invite_id"], name: "index_request_items_on_invite_id"
  end

  create_table "uploaded_files", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "request_item_id", null: false
    t.uuid "uploaded_by_contact_id"
    t.uuid "reviewed_by_id"
    t.string "storage_key", null: false
    t.string "filename", null: false
    t.string "content_type", null: false
    t.bigint "byte_size"
    t.string "status", default: "uploaded", null: false
    t.text "rejection_reason"
    t.datetime "reviewed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["request_item_id"], name: "index_uploaded_files_on_request_item_id"
    t.index ["reviewed_by_id"], name: "index_uploaded_files_on_reviewed_by_id"
    t.index ["storage_key"], name: "index_uploaded_files_on_storage_key", unique: true
    t.index ["uploaded_by_contact_id"], name: "index_uploaded_files_on_uploaded_by_contact_id"
  end

  create_table "users", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "company_id", null: false
    t.string "name", null: false
    t.string "email", null: false
    t.string "password_digest", null: false
    t.string "role", default: "member", null: false
    t.datetime "last_login_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.integer "sign_in_count", default: 0, null: false
    t.datetime "current_sign_in_at"
    t.datetime "last_sign_in_at"
    t.string "current_sign_in_ip"
    t.string "last_sign_in_ip"
    t.integer "failed_attempts", default: 0, null: false
    t.string "unlock_token"
    t.datetime "locked_at"
    t.string "confirmation_token"
    t.datetime "confirmed_at"
    t.datetime "confirmation_sent_at"
    t.string "unconfirmed_email"
    t.integer "password_archived_count", default: 0
    t.datetime "password_changed_at"
    t.boolean "allow_password_change", default: false
    t.index ["company_id", "email"], name: "index_users_on_company_id_and_email", unique: true
    t.index ["company_id"], name: "index_users_on_company_id"
    t.index ["confirmation_token"], name: "index_users_on_confirmation_token", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["unlock_token"], name: "index_users_on_unlock_token", unique: true
  end

  add_foreign_key "audit_events", "companies"
  add_foreign_key "audit_events", "contacts"
  add_foreign_key "audit_events", "invites"
  add_foreign_key "audit_events", "users"
  add_foreign_key "company_memberships", "companies"
  add_foreign_key "company_memberships", "users"
  add_foreign_key "contacts", "companies"
  add_foreign_key "invite_contacts", "contacts"
  add_foreign_key "invite_contacts", "invites"
  add_foreign_key "invites", "companies"
  add_foreign_key "invites", "contacts"
  add_foreign_key "invites", "users", column: "created_by_id"
  add_foreign_key "reminders", "invites"
  add_foreign_key "request_items", "invites"
  add_foreign_key "uploaded_files", "contacts", column: "uploaded_by_contact_id"
  add_foreign_key "uploaded_files", "request_items"
  add_foreign_key "uploaded_files", "users", column: "reviewed_by_id"
  add_foreign_key "users", "companies"
end
