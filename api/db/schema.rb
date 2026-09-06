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

ActiveRecord::Schema[8.1].define(version: 2026_09_06_165511) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "admins", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email"
    t.string "google_uid"
    t.string "name"
    t.datetime "updated_at", null: false
  end

  create_table "application_settings", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.jsonb "settings", default: {}, null: false
    t.datetime "updated_at", null: false
  end

  create_table "card_styles", force: :cascade do |t|
    t.bigint "card_id", null: false
    t.datetime "created_at", null: false
    t.bigint "style_id", null: false
    t.datetime "updated_at", null: false
    t.index ["card_id"], name: "index_card_styles_on_card_id"
    t.index ["style_id"], name: "index_card_styles_on_style_id"
  end

  create_table "cards", force: :cascade do |t|
    t.text "contributor_prompt"
    t.datetime "created_at", null: false
    t.datetime "deleted_at"
    t.datetime "deliver_at"
    t.string "deliver_to_email"
    t.string "external_id", null: false
    t.datetime "flagged_at"
    t.string "kind", default: "group", null: false
    t.datetime "locked_at"
    t.integer "max_messages", default: 20, null: false
    t.string "occasion"
    t.bigint "organization_id"
    t.jsonb "recipients", default: [], null: false
    t.boolean "require_login_to_contribute", default: false, null: false
    t.string "slug"
    t.string "title"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["deleted_at"], name: "index_cards_on_deleted_at"
    t.index ["external_id"], name: "index_cards_on_external_id", unique: true
    t.index ["organization_id"], name: "index_cards_on_organization_id"
    t.index ["slug"], name: "index_cards_on_slug", unique: true, where: "(slug IS NOT NULL)"
    t.index ["user_id"], name: "index_cards_on_user_id"
  end

  create_table "contact_list_memberships", force: :cascade do |t|
    t.bigint "contact_id", null: false
    t.bigint "contact_list_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["contact_id"], name: "index_contact_list_memberships_on_contact_id"
    t.index ["contact_list_id", "contact_id"], name: "idx_on_contact_list_id_contact_id_4784adb2b8", unique: true
    t.index ["contact_list_id"], name: "index_contact_list_memberships_on_contact_list_id"
  end

  create_table "contact_lists", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["user_id", "name"], name: "index_contact_lists_on_user_id_and_name", unique: true
    t.index ["user_id"], name: "index_contact_lists_on_user_id"
  end

  create_table "contacts", force: :cascade do |t|
    t.string "address_line1"
    t.string "address_line2"
    t.string "address_verification_status"
    t.datetime "address_verified_at"
    t.string "address_zone"
    t.string "city"
    t.string "country_code"
    t.datetime "created_at", null: false
    t.string "email"
    t.string "name", null: false
    t.text "notes"
    t.string "phone"
    t.string "postal_code"
    t.string "region"
    t.string "relationship"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["user_id"], name: "index_contacts_on_user_id"
  end

  create_table "credits", force: :cascade do |t|
    t.integer "amount"
    t.datetime "created_at", null: false
    t.jsonb "events"
    t.string "reason"
    t.string "stripe_session_id"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["user_id"], name: "index_credits_on_user_id"
  end

  create_table "good_job_batches", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.integer "callback_priority"
    t.text "callback_queue_name"
    t.datetime "created_at", null: false
    t.text "description"
    t.datetime "discarded_at"
    t.datetime "enqueued_at"
    t.datetime "finished_at"
    t.datetime "jobs_finished_at"
    t.text "on_discard"
    t.text "on_finish"
    t.text "on_success"
    t.jsonb "serialized_properties"
    t.datetime "updated_at", null: false
  end

  create_table "good_job_executions", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "active_job_id", null: false
    t.datetime "created_at", null: false
    t.interval "duration"
    t.text "error"
    t.text "error_backtrace", array: true
    t.integer "error_event", limit: 2
    t.datetime "finished_at"
    t.text "job_class"
    t.uuid "process_id"
    t.text "queue_name"
    t.datetime "scheduled_at"
    t.jsonb "serialized_params"
    t.datetime "updated_at", null: false
    t.index ["active_job_id", "created_at"], name: "index_good_job_executions_on_active_job_id_and_created_at"
    t.index ["process_id", "created_at"], name: "index_good_job_executions_on_process_id_and_created_at"
  end

  create_table "good_job_processes", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "lock_type", limit: 2
    t.jsonb "state"
    t.datetime "updated_at", null: false
  end

  create_table "good_job_settings", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "key"
    t.datetime "updated_at", null: false
    t.jsonb "value"
    t.index ["key"], name: "index_good_job_settings_on_key", unique: true
  end

  create_table "good_jobs", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "active_job_id"
    t.uuid "batch_callback_id"
    t.uuid "batch_id"
    t.text "concurrency_key"
    t.datetime "created_at", null: false
    t.datetime "cron_at"
    t.text "cron_key"
    t.text "error"
    t.integer "error_event", limit: 2
    t.integer "executions_count"
    t.datetime "finished_at"
    t.boolean "is_discrete"
    t.text "job_class"
    t.text "labels", array: true
    t.integer "lock_type", limit: 2
    t.datetime "locked_at"
    t.uuid "locked_by_id"
    t.datetime "performed_at"
    t.integer "priority"
    t.text "queue_name"
    t.uuid "retried_good_job_id"
    t.datetime "scheduled_at"
    t.jsonb "serialized_params"
    t.datetime "updated_at", null: false
    t.index ["active_job_id", "created_at"], name: "index_good_jobs_on_active_job_id_and_created_at"
    t.index ["batch_callback_id"], name: "index_good_jobs_on_batch_callback_id", where: "(batch_callback_id IS NOT NULL)"
    t.index ["batch_id"], name: "index_good_jobs_on_batch_id", where: "(batch_id IS NOT NULL)"
    t.index ["concurrency_key", "created_at"], name: "index_good_jobs_on_concurrency_key_and_created_at"
    t.index ["concurrency_key"], name: "index_good_jobs_on_concurrency_key_when_unfinished", where: "(finished_at IS NULL)"
    t.index ["created_at"], name: "index_good_jobs_on_created_at"
    t.index ["cron_key", "created_at"], name: "index_good_jobs_on_cron_key_and_created_at_cond", where: "(cron_key IS NOT NULL)"
    t.index ["cron_key", "cron_at"], name: "index_good_jobs_on_cron_key_and_cron_at_cond", unique: true, where: "(cron_key IS NOT NULL)"
    t.index ["finished_at"], name: "index_good_jobs_jobs_on_finished_at_only", where: "(finished_at IS NOT NULL)"
    t.index ["finished_at"], name: "index_good_jobs_on_discarded", order: :desc, where: "((finished_at IS NOT NULL) AND (error IS NOT NULL))"
    t.index ["id"], name: "index_good_jobs_on_unfinished_or_errored", where: "((finished_at IS NULL) OR (error IS NOT NULL))"
    t.index ["job_class"], name: "index_good_jobs_on_job_class"
    t.index ["labels"], name: "index_good_jobs_on_labels", where: "(labels IS NOT NULL)", using: :gin
    t.index ["locked_by_id"], name: "index_good_jobs_on_locked_by_id", where: "(locked_by_id IS NOT NULL)"
    t.index ["priority", "created_at"], name: "index_good_job_jobs_for_candidate_lookup", where: "(finished_at IS NULL)"
    t.index ["priority", "created_at"], name: "index_good_jobs_jobs_on_priority_created_at_when_unfinished", order: { priority: "DESC NULLS LAST" }, where: "(finished_at IS NULL)"
    t.index ["priority", "scheduled_at", "id"], name: "index_good_jobs_for_candidate_dequeue_unlocked", where: "((finished_at IS NULL) AND (locked_by_id IS NULL))"
    t.index ["priority", "scheduled_at", "id"], name: "index_good_jobs_on_priority_scheduled_at_unfinished", where: "(finished_at IS NULL)"
    t.index ["priority", "scheduled_at"], name: "index_good_jobs_on_priority_scheduled_at_unfinished_unlocked", where: "((finished_at IS NULL) AND (locked_by_id IS NULL))"
    t.index ["queue_name", "scheduled_at", "id"], name: "index_good_jobs_on_queue_name_priority_scheduled_at_unfinished", where: "(finished_at IS NULL)"
    t.index ["queue_name", "scheduled_at"], name: "index_good_jobs_on_queue_name_and_scheduled_at", where: "(finished_at IS NULL)"
    t.index ["queue_name"], name: "index_good_jobs_on_queue_name"
    t.index ["scheduled_at", "queue_name"], name: "index_good_jobs_on_scheduled_at_and_queue_name"
    t.index ["scheduled_at"], name: "index_good_jobs_on_scheduled_at", where: "(finished_at IS NULL)"
  end

  create_table "guest_messages", force: :cascade do |t|
    t.bigint "card_id", null: false
    t.datetime "created_at", null: false
    t.datetime "deleted_at"
    t.jsonb "details", default: {}
    t.datetime "flagged_at"
    t.string "name"
    t.text "text"
    t.string "title"
    t.datetime "updated_at", null: false
    t.index ["card_id"], name: "index_guest_messages_on_card_id"
    t.index ["deleted_at"], name: "index_guest_messages_on_deleted_at"
  end

  create_table "holiday_cards", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "deleted_at"
    t.jsonb "design_config", default: {}, null: false
    t.string "external_id", null: false
    t.datetime "proof_approved_at"
    t.string "proof_design_digest"
    t.datetime "proof_generated_at"
    t.string "proof_url"
    t.string "size", default: "6x4", null: false
    t.string "template_id", null: false
    t.string "title"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["deleted_at"], name: "index_holiday_cards_on_deleted_at"
    t.index ["external_id"], name: "index_holiday_cards_on_external_id", unique: true
    t.index ["user_id"], name: "index_holiday_cards_on_user_id"
  end

  create_table "invitations", force: :cascade do |t|
    t.boolean "allow_plus_one"
    t.string "attire"
    t.datetime "created_at", null: false
    t.text "custom_instructions"
    t.text "description"
    t.date "event_date"
    t.string "event_time"
    t.string "event_timezone"
    t.string "external_id"
    t.string "location"
    t.integer "max_additional_guests", default: 1
    t.string "opening_message"
    t.jsonb "opening_message_config"
    t.bigint "organization_id"
    t.date "rsvp_deadline"
    t.string "slug"
    t.string "title"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.jsonb "wish_list_items"
    t.index ["external_id"], name: "index_invitations_on_external_id", unique: true
    t.index ["organization_id"], name: "index_invitations_on_organization_id"
    t.index ["slug"], name: "index_invitations_on_slug", unique: true, where: "(slug IS NOT NULL)"
    t.index ["user_id"], name: "index_invitations_on_user_id"
  end

  create_table "messages", force: :cascade do |t|
    t.bigint "card_id", null: false
    t.datetime "created_at", null: false
    t.datetime "deleted_at"
    t.jsonb "details", default: {}
    t.string "display_name"
    t.datetime "flagged_at"
    t.text "text", null: false
    t.string "title"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["card_id"], name: "index_messages_on_card_id"
    t.index ["deleted_at"], name: "index_messages_on_deleted_at"
    t.index ["user_id"], name: "index_messages_on_user_id"
  end

  create_table "occasions", force: :cascade do |t|
    t.bigint "contact_id", null: false
    t.datetime "created_at", null: false
    t.string "kind", null: false
    t.datetime "last_reminded_at"
    t.date "occurs_on", null: false
    t.boolean "recurring", default: true, null: false
    t.integer "reminder_lead_days", default: 7
    t.datetime "updated_at", null: false
    t.index ["contact_id"], name: "index_occasions_on_contact_id"
    t.index ["occurs_on"], name: "index_occasions_on_occurs_on"
  end

  create_table "organization_credits", force: :cascade do |t|
    t.integer "amount"
    t.datetime "created_at", null: false
    t.jsonb "events"
    t.bigint "organization_id", null: false
    t.string "reason"
    t.string "stripe_session_id"
    t.datetime "updated_at", null: false
    t.index ["organization_id"], name: "index_organization_credits_on_organization_id"
  end

  create_table "organization_invitations", force: :cascade do |t|
    t.datetime "accepted_at"
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.datetime "expires_at", null: false
    t.bigint "invited_by_id", null: false
    t.bigint "organization_id", null: false
    t.string "role", default: "member", null: false
    t.string "status", default: "pending", null: false
    t.string "token", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_organization_invitations_on_email"
    t.index ["invited_by_id"], name: "index_organization_invitations_on_invited_by_id"
    t.index ["organization_id", "email"], name: "index_organization_invitations_on_org_and_pending_email", unique: true, where: "((status)::text = 'pending'::text)"
    t.index ["organization_id"], name: "index_organization_invitations_on_organization_id"
    t.index ["token"], name: "index_organization_invitations_on_token", unique: true
  end

  create_table "organization_memberships", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "organization_id", null: false
    t.string "role", default: "member", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["organization_id", "role"], name: "index_organization_memberships_on_organization_id_and_role"
    t.index ["organization_id", "user_id"], name: "index_organization_memberships_on_organization_id_and_user_id", unique: true
    t.index ["organization_id"], name: "index_organization_memberships_on_organization_id"
    t.index ["user_id"], name: "index_organization_memberships_on_user_id"
  end

  create_table "organizations", force: :cascade do |t|
    t.string "accent_color"
    t.datetime "created_at", null: false
    t.bigint "created_by_id", null: false
    t.datetime "deleted_at"
    t.text "description"
    t.string "email_footer_text"
    t.string "email_reply_to"
    t.string "name", null: false
    t.string "slug", null: false
    t.datetime "updated_at", null: false
    t.index ["created_by_id"], name: "index_organizations_on_created_by_id"
    t.index ["deleted_at"], name: "index_organizations_on_deleted_at"
    t.index ["slug"], name: "index_organizations_on_slug", unique: true
  end

  create_table "postage_credits", force: :cascade do |t|
    t.integer "amount_cents", null: false
    t.datetime "created_at", null: false
    t.jsonb "events"
    t.string "reason"
    t.string "stripe_session_id"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["user_id"], name: "index_postage_credits_on_user_id"
  end

  create_table "promo_code_redemptions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "promo_code_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["promo_code_id"], name: "index_promo_code_redemptions_on_promo_code_id"
    t.index ["user_id"], name: "index_promo_code_redemptions_on_user_id"
  end

  create_table "promo_codes", force: :cascade do |t|
    t.string "code"
    t.datetime "created_at", null: false
    t.integer "credit_amount"
    t.datetime "expires_at"
    t.integer "times_redeemed"
    t.datetime "updated_at", null: false
    t.integer "usage_limit"
    t.bigint "user_id"
    t.index ["code"], name: "index_promo_codes_on_code", unique: true
    t.index ["user_id"], name: "index_promo_codes_on_user_id"
  end

  create_table "rsvps", force: :cascade do |t|
    t.integer "additional_guests_count", default: 0
    t.datetime "created_at", null: false
    t.string "guest_email"
    t.string "guest_name"
    t.bigint "invitation_id", null: false
    t.text "message"
    t.boolean "plus_one"
    t.string "plus_one_name"
    t.string "status"
    t.datetime "updated_at", null: false
    t.bigint "user_id"
    t.index ["invitation_id"], name: "index_rsvps_on_invitation_id"
    t.index ["user_id"], name: "index_rsvps_on_user_id"
  end

  create_table "slack_installations", force: :cascade do |t|
    t.string "access_token", null: false
    t.datetime "created_at", null: false
    t.string "team_id", null: false
    t.string "team_name", null: false
    t.datetime "updated_at", null: false
    t.index ["team_id"], name: "index_slack_installations_on_team_id", unique: true
  end

  create_table "slack_user_connections", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "slack_team_id", null: false
    t.string "slack_user_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["slack_user_id", "slack_team_id"], name: "idx_on_slack_user_id_slack_team_id_ce39740193", unique: true
    t.index ["user_id"], name: "index_slack_user_connections_on_user_id"
  end

  create_table "style_tags", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "style_id", null: false
    t.bigint "tag_id", null: false
    t.datetime "updated_at", null: false
    t.index ["style_id"], name: "index_style_tags_on_style_id"
    t.index ["tag_id"], name: "index_style_tags_on_tag_id"
  end

  create_table "styles", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "deleted_at"
    t.string "kind"
    t.string "name"
    t.bigint "organization_id"
    t.string "source"
    t.datetime "updated_at", null: false
    t.index ["organization_id"], name: "index_styles_on_organization_id"
  end

  create_table "tags", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name"
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_tags_on_name", unique: true
  end

  create_table "users", force: :cascade do |t|
    t.bigint "active_organization_id"
    t.string "confirmation_code"
    t.datetime "confirmation_sent_at"
    t.datetime "created_at", null: false
    t.string "email", default: "", null: false
    t.boolean "email_confirmed", default: false
    t.string "encrypted_password", default: "", null: false
    t.string "name", default: "", null: false
    t.string "provider"
    t.datetime "remember_created_at"
    t.datetime "reset_password_sent_at"
    t.string "reset_password_token"
    t.string "stripe_customer_id"
    t.string "uid"
    t.datetime "updated_at", null: false
    t.index ["active_organization_id"], name: "index_users_on_active_organization_id"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["provider", "uid"], name: "index_users_on_provider_and_uid", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  create_table "wish_list_contributions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "handle", null: false
    t.string "kind", null: false
    t.string "label"
    t.text "note"
    t.integer "position", default: 0, null: false
    t.string "suggested_amount"
    t.datetime "updated_at", null: false
    t.bigint "wish_list_id", null: false
    t.index ["wish_list_id", "position"], name: "index_wish_list_contributions_on_wish_list_id_and_position"
    t.index ["wish_list_id"], name: "index_wish_list_contributions_on_wish_list_id"
  end

  create_table "wish_list_items", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "image_url"
    t.text "note"
    t.integer "position", default: 0, null: false
    t.string "price"
    t.integer "quantity", default: 1, null: false
    t.string "store"
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.string "url"
    t.bigint "wish_list_id", null: false
    t.index ["wish_list_id", "position"], name: "index_wish_list_items_on_wish_list_id_and_position"
    t.index ["wish_list_id"], name: "index_wish_list_items_on_wish_list_id"
  end

  create_table "wish_lists", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "intro"
    t.bigint "invitation_id", null: false
    t.boolean "surprise_mode", default: true, null: false
    t.string "title", default: "Wish List", null: false
    t.datetime "updated_at", null: false
    t.boolean "visible", default: true, null: false
    t.index ["invitation_id"], name: "index_wish_lists_on_invitation_id", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "card_styles", "cards"
  add_foreign_key "card_styles", "styles"
  add_foreign_key "cards", "organizations", on_delete: :nullify
  add_foreign_key "cards", "users"
  add_foreign_key "contact_list_memberships", "contact_lists"
  add_foreign_key "contact_list_memberships", "contacts"
  add_foreign_key "contact_lists", "users"
  add_foreign_key "contacts", "users"
  add_foreign_key "credits", "users"
  add_foreign_key "guest_messages", "cards"
  add_foreign_key "holiday_cards", "users"
  add_foreign_key "invitations", "organizations", on_delete: :nullify
  add_foreign_key "invitations", "users"
  add_foreign_key "messages", "cards"
  add_foreign_key "messages", "users"
  add_foreign_key "occasions", "contacts"
  add_foreign_key "organization_credits", "organizations"
  add_foreign_key "organization_invitations", "organizations"
  add_foreign_key "organization_invitations", "users", column: "invited_by_id"
  add_foreign_key "organization_memberships", "organizations"
  add_foreign_key "organization_memberships", "users"
  add_foreign_key "organizations", "users", column: "created_by_id"
  add_foreign_key "postage_credits", "users"
  add_foreign_key "promo_code_redemptions", "promo_codes"
  add_foreign_key "promo_code_redemptions", "users"
  add_foreign_key "promo_codes", "users"
  add_foreign_key "rsvps", "invitations"
  add_foreign_key "rsvps", "users"
  add_foreign_key "slack_user_connections", "users"
  add_foreign_key "style_tags", "styles"
  add_foreign_key "style_tags", "tags"
  add_foreign_key "styles", "organizations", on_delete: :cascade
  add_foreign_key "users", "organizations", column: "active_organization_id", on_delete: :nullify
  add_foreign_key "wish_list_contributions", "wish_lists"
  add_foreign_key "wish_list_items", "wish_lists"
  add_foreign_key "wish_lists", "invitations"
end
