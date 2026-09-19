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

ActiveRecord::Schema[8.1].define(version: 2026_09_19_120003) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "vector"

  create_table "api_keys", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "last_used_at"
    t.string "name", null: false
    t.bigint "tenant_id", null: false
    t.string "token_digest", null: false
    t.string "token_prefix", null: false
    t.datetime "updated_at", null: false
    t.index ["tenant_id"], name: "index_api_keys_on_tenant_id"
    t.index ["token_digest"], name: "index_api_keys_on_token_digest", unique: true
    t.index ["token_prefix"], name: "index_api_keys_on_token_prefix"
  end

  create_table "chunks", force: :cascade do |t|
    t.text "content", null: false
    t.datetime "created_at", null: false
    t.bigint "document_id", null: false
    t.vector "embedding", limit: 1536
    t.integer "position", null: false
    t.bigint "tenant_id", null: false
    t.datetime "updated_at", null: false
    t.index ["document_id", "position"], name: "index_chunks_on_document_id_and_position", unique: true
    t.index ["document_id"], name: "index_chunks_on_document_id"
    t.index ["tenant_id"], name: "index_chunks_on_tenant_id"
  end

  create_table "documents", force: :cascade do |t|
    t.text "content"
    t.datetime "created_at", null: false
    t.text "error_message"
    t.string "source_type", default: "text", null: false
    t.string "status", default: "pending", null: false
    t.bigint "tenant_id", null: false
    t.string "title"
    t.datetime "updated_at", null: false
    t.index ["tenant_id", "status"], name: "index_documents_on_tenant_id_and_status"
    t.index ["tenant_id"], name: "index_documents_on_tenant_id"
  end

  create_table "tenants", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
  end

  add_foreign_key "api_keys", "tenants"
  add_foreign_key "chunks", "documents"
  add_foreign_key "chunks", "tenants"
  add_foreign_key "documents", "tenants"
end
