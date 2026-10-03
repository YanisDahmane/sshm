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

ActiveRecord::Schema[8.0].define(version: 2026_10_03_201517) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "account_snapshots", force: :cascade do |t|
    t.bigint "server_id", null: false
    t.string "unix_user", null: false
    t.text "content", default: "", null: false
    t.datetime "read_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["server_id", "unix_user"], name: "index_account_snapshots_on_server_id_and_unix_user", unique: true
    t.index ["server_id"], name: "index_account_snapshots_on_server_id"
  end

  create_table "activities", force: :cascade do |t|
    t.string "kind", null: false
    t.bigint "user_id"
    t.bigint "server_id"
    t.bigint "profile_id"
    t.string "unix_user"
    t.jsonb "data", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_at"], name: "index_activities_on_created_at"
    t.index ["kind"], name: "index_activities_on_kind"
    t.index ["profile_id"], name: "index_activities_on_profile_id"
    t.index ["server_id"], name: "index_activities_on_server_id"
    t.index ["user_id"], name: "index_activities_on_user_id"
  end

  create_table "automations", force: :cascade do |t|
    t.string "kind", null: false
    t.boolean "enabled", default: false, null: false
    t.integer "interval_minutes", null: false
    t.datetime "last_run_at"
    t.string "last_result"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["kind"], name: "index_automations_on_kind", unique: true
  end

  create_table "notification_channels", force: :cascade do |t|
    t.string "name", null: false
    t.string "kind", default: "slack", null: false
    t.text "webhook_url", null: false
    t.jsonb "activity_kinds", default: [], null: false
    t.boolean "mention_channel", default: false, null: false
    t.boolean "enabled", default: true, null: false
    t.datetime "last_delivered_at"
    t.text "last_error"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_notification_channels_on_name", unique: true
  end

  create_table "profiles", force: :cascade do |t|
    t.string "name", null: false
    t.text "public_key", null: false
    t.string "fingerprint", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["fingerprint"], name: "index_profiles_on_fingerprint", unique: true
    t.index ["name"], name: "index_profiles_on_name", unique: true
  end

  create_table "servers", force: :cascade do |t|
    t.string "name", null: false
    t.string "host", null: false
    t.integer "port", default: 22, null: false
    t.string "username", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "reachable"
    t.datetime "last_checked_at"
    t.boolean "ssh_ok"
    t.datetime "ssh_checked_at"
    t.index ["name"], name: "index_servers_on_name", unique: true
  end

  create_table "ssh_keys", force: :cascade do |t|
    t.text "public_key", null: false
    t.text "private_key", null: false
    t.string "fingerprint", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "temporary_accesses", force: :cascade do |t|
    t.bigint "server_id", null: false
    t.bigint "profile_id"
    t.string "unix_user", null: false
    t.text "key_blob", null: false
    t.string "fingerprint", null: false
    t.datetime "expires_at", null: false
    t.datetime "ended_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["expires_at"], name: "index_temporary_accesses_active_expiry", where: "(ended_at IS NULL)"
    t.index ["profile_id"], name: "index_temporary_accesses_on_profile_id"
    t.index ["server_id", "unix_user", "fingerprint"], name: "index_temporary_accesses_active_key", unique: true, where: "(ended_at IS NULL)"
    t.index ["server_id"], name: "index_temporary_accesses_on_server_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  add_foreign_key "account_snapshots", "servers", on_delete: :cascade
  add_foreign_key "activities", "profiles", on_delete: :nullify
  add_foreign_key "activities", "servers", on_delete: :nullify
  add_foreign_key "activities", "users", on_delete: :nullify
  add_foreign_key "temporary_accesses", "profiles", on_delete: :nullify
  add_foreign_key "temporary_accesses", "servers", on_delete: :cascade
end
