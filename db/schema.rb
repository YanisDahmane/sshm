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

ActiveRecord::Schema[8.0].define(version: 2026_10_03_163057) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

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

  add_foreign_key "temporary_accesses", "profiles", on_delete: :nullify
  add_foreign_key "temporary_accesses", "servers", on_delete: :cascade
end
