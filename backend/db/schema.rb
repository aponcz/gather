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

ActiveRecord::Schema[7.1].define(version: 2026_06_30_160000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pgcrypto"
  enable_extension "plpgsql"

  create_table "audit_events", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "organization_id", null: false
    t.uuid "invite_id"
    t.uuid "user_id"
    t.uuid "contact_id"
    t.string "action", null: false
    t.string "ip_address"
    t.string "user_agent"
    t.jsonb "metadata", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["contact_id"], name: "index_audit_events_on_contact_id"
    t.index ["invite_id"], name: "index_audit_events_on_invite_id"
    t.index ["organization_id", "created_at"], name: "index_audit_events_on_organization_id_and_created_at"
    t.index ["organization_id"], name: "index_audit_events_on_organization_id"
    t.index ["user_id"], name: "index_audit_events_on_user_id"
  end

  create_table "contacts", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "organization_id", null: false
    t.string "name", null: false
    t.string "email", null: false
    t.string "phone"
    t.string "external_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["organization_id", "email"], name: "index_contacts_on_organization_id_and_email", unique: true
    t.index ["organization_id"], name: "index_contacts_on_organization_id"
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
    t.uuid "organization_id", null: false
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
    t.index ["contact_id"], name: "index_invites_on_contact_id"
    t.index ["created_by_id"], name: "index_invites_on_created_by_id"
    t.index ["organization_id", "status"], name: "index_invites_on_organization_id_and_status"
    t.index ["organization_id"], name: "index_invites_on_organization_id"
    t.index ["public_token"], name: "index_invites_on_public_token", unique: true
  end

  create_table "organizations", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "name", null: false
    t.string "subdomain"
    t.string "brand_color"
    t.string "logo_url"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["subdomain"], name: "index_organizations_on_subdomain", unique: true
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
    t.uuid "organization_id", null: false
    t.string "name", null: false
    t.string "email", null: false
    t.string "password_digest", null: false
    t.string "role", default: "member", null: false
    t.datetime "last_login_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["organization_id", "email"], name: "index_users_on_organization_id_and_email", unique: true
    t.index ["organization_id"], name: "index_users_on_organization_id"
  end

  add_foreign_key "audit_events", "contacts"
  add_foreign_key "audit_events", "invites"
  add_foreign_key "audit_events", "organizations"
  add_foreign_key "audit_events", "users"
  add_foreign_key "contacts", "organizations"
  add_foreign_key "invite_contacts", "contacts"
  add_foreign_key "invite_contacts", "invites"
  add_foreign_key "invites", "contacts"
  add_foreign_key "invites", "organizations"
  add_foreign_key "invites", "users", column: "created_by_id"
  add_foreign_key "reminders", "invites"
  add_foreign_key "request_items", "invites"
  add_foreign_key "uploaded_files", "contacts", column: "uploaded_by_contact_id"
  add_foreign_key "uploaded_files", "request_items"
  add_foreign_key "uploaded_files", "users", column: "reviewed_by_id"
  add_foreign_key "users", "organizations"
end
