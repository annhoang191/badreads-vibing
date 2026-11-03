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

ActiveRecord::Schema[8.0].define(version: 2026_11_03_110523) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "citext"
  enable_extension "pg_catalog.plpgsql"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "books", force: :cascade do |t|
    t.string "source", default: "goodreads", null: false
    t.string "goodreads_book_id"
    t.string "isbn"
    t.string "isbn13"
    t.string "title", null: false
    t.string "author"
    t.string "additional_authors", default: [], null: false, array: true
    t.integer "num_pages"
    t.integer "year_published"
    t.integer "original_publication_year"
    t.decimal "avg_rating", precision: 3, scale: 2
    t.string "open_library_work_key"
    t.jsonb "subjects", default: [], null: false
    t.string "cover_url"
    t.string "enrichment_status", default: "pending", null: false
    t.datetime "enriched_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["goodreads_book_id"], name: "index_books_on_goodreads_book_id", unique: true, where: "(goodreads_book_id IS NOT NULL)"
    t.index ["isbn13"], name: "index_books_on_isbn13"
    t.index ["open_library_work_key"], name: "index_books_on_open_library_work_key", unique: true, where: "(open_library_work_key IS NOT NULL)"
  end

  create_table "goodreads_profiles", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "goodreads_user_id", null: false
    t.boolean "rss_enabled", default: false, null: false
    t.datetime "last_synced_at"
    t.integer "consecutive_failures", default: 0, null: false
    t.text "last_error"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_goodreads_profiles_on_user_id", unique: true
  end

  create_table "imports", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "source", null: false
    t.string "status", default: "pending", null: false
    t.string "filename"
    t.jsonb "stats", default: {}, null: false
    t.text "error_message"
    t.datetime "started_at"
    t.datetime "finished_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id", "created_at"], name: "index_imports_on_user_id_and_created_at"
  end

  create_table "llm_calls", force: :cascade do |t|
    t.bigint "recommendation_batch_id"
    t.string "task", null: false
    t.string "tier", null: false
    t.string "model", null: false
    t.integer "input_tokens", default: 0, null: false
    t.integer "output_tokens", default: 0, null: false
    t.integer "cache_read_tokens", default: 0, null: false
    t.integer "cache_write_tokens", default: 0, null: false
    t.decimal "cost_usd", precision: 10, scale: 6, default: "0.0", null: false
    t.integer "latency_ms"
    t.string "stop_reason"
    t.text "error"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["recommendation_batch_id"], name: "index_llm_calls_on_recommendation_batch_id"
    t.index ["task", "created_at"], name: "index_llm_calls_on_task_and_created_at"
  end

  create_table "reading_insights", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.integer "version", default: 1, null: false
    t.jsonb "data", default: {}, null: false
    t.datetime "computed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_reading_insights_on_user_id", unique: true
  end

  create_table "recommendation_batches", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "status", default: "pending", null: false
    t.string "ranked_by"
    t.string "prompt_version"
    t.decimal "total_cost_usd", precision: 10, scale: 6, default: "0.0", null: false
    t.jsonb "cost_by_tier", default: {}, null: false
    t.integer "agent_turns"
    t.text "error_message"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id", "created_at"], name: "index_recommendation_batches_on_user_id_and_created_at"
  end

  create_table "recommendations", force: :cascade do |t|
    t.bigint "recommendation_batch_id", null: false
    t.bigint "user_id", null: false
    t.bigint "book_id", null: false
    t.integer "position", null: false
    t.integer "score"
    t.text "reason"
    t.string "status", default: "new", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["book_id"], name: "index_recommendations_on_book_id"
    t.index ["recommendation_batch_id", "book_id"], name: "index_recommendations_on_recommendation_batch_id_and_book_id", unique: true
    t.index ["user_id", "status"], name: "index_recommendations_on_user_id_and_status"
    t.check_constraint "\"position\" >= 1 AND \"position\" <= 10", name: "recommendations_position_range"
  end

  create_table "sessions", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "token", null: false
    t.string "ip_address"
    t.string "user_agent"
    t.datetime "last_used_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["token"], name: "index_sessions_on_token", unique: true
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "subject_mappings", force: :cascade do |t|
    t.string "raw_subject", null: false
    t.string "canonical_subject"
    t.string "source", default: "config", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["raw_subject"], name: "index_subject_mappings_on_raw_subject", unique: true
  end

  create_table "user_books", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "book_id", null: false
    t.string "exclusive_shelf", null: false
    t.string "shelves", default: [], null: false, array: true
    t.integer "my_rating"
    t.date "date_read"
    t.date "date_added"
    t.integer "read_count", default: 0, null: false
    t.text "review"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["book_id"], name: "index_user_books_on_book_id"
    t.index ["user_id", "book_id"], name: "index_user_books_on_user_id_and_book_id", unique: true
    t.index ["user_id", "exclusive_shelf"], name: "index_user_books_on_user_id_and_exclusive_shelf"
    t.check_constraint "my_rating IS NULL OR my_rating >= 1 AND my_rating <= 5", name: "user_books_my_rating_range"
  end

  create_table "users", force: :cascade do |t|
    t.citext "email_address", null: false
    t.string "password_digest", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "goodreads_profiles", "users", on_delete: :cascade
  add_foreign_key "imports", "users", on_delete: :cascade
  add_foreign_key "llm_calls", "recommendation_batches", on_delete: :cascade
  add_foreign_key "reading_insights", "users", on_delete: :cascade
  add_foreign_key "recommendation_batches", "users", on_delete: :cascade
  add_foreign_key "recommendations", "books"
  add_foreign_key "recommendations", "recommendation_batches", on_delete: :cascade
  add_foreign_key "recommendations", "users", on_delete: :cascade
  add_foreign_key "sessions", "users", on_delete: :cascade
  add_foreign_key "user_books", "books"
  add_foreign_key "user_books", "users", on_delete: :cascade
end
