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

ActiveRecord::Schema[8.1].define(version: 2026_06_23_171756) do
  create_table "acceptance_submissions", force: :cascade do |t|
    t.integer "attachment_id"
    t.datetime "created_at", null: false
    t.integer "delivery_note_id", null: false
    t.datetime "reviewed_at"
    t.integer "reviewed_by_id"
    t.string "status", default: "pending", null: false
    t.datetime "submitted_at", null: false
    t.string "submitted_ip"
    t.datetime "updated_at", null: false
    t.index ["attachment_id"], name: "index_acceptance_submissions_on_attachment_id"
    t.index ["delivery_note_id"], name: "index_acceptance_submissions_on_delivery_note_id"
    t.index ["delivery_note_id"], name: "index_one_pending_submission_per_note", unique: true, where: "status = 'pending'"
    t.index ["reviewed_by_id"], name: "index_acceptance_submissions_on_reviewed_by_id"
  end

  create_table "attachments", force: :cascade do |t|
    t.string "content_type"
    t.datetime "created_at", null: false
    t.binary "data"
    t.string "filename"
    t.string "title"
    t.datetime "updated_at", null: false
  end

  create_table "customer_contact_projects", force: :cascade do |t|
    t.integer "customer_contact_id", null: false
    t.integer "project_id", null: false
    t.index ["customer_contact_id", "project_id"], name: "index_customer_contact_projects_uniq", unique: true
    t.index ["customer_contact_id"], name: "index_customer_contact_projects_on_customer_contact_id"
    t.index ["project_id"], name: "index_customer_contact_projects_on_project_id"
  end

  create_table "customer_contacts", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "customer_id", null: false
    t.string "email", null: false
    t.string "name", null: false
    t.boolean "receives_delivery_note_emails", default: false, null: false
    t.boolean "receives_invoice_emails", default: false, null: false
    t.string "salutation_line"
    t.datetime "updated_at", null: false
    t.index ["customer_id"], name: "index_customer_contacts_on_customer_id"
  end

  create_table "customer_vat_verifications", force: :cascade do |t|
    t.string "country_iso2", limit: 2
    t.datetime "created_at", null: false
    t.integer "customer_id", null: false
    t.text "error_code"
    t.datetime "notified_at"
    t.integer "performed_by_user_id"
    t.text "raw_response"
    t.datetime "request_date"
    t.text "request_identifier"
    t.text "trader_address"
    t.text "trader_name"
    t.datetime "updated_at", null: false
    t.boolean "valid_response"
    t.text "vat_id", null: false
    t.index ["customer_id", "created_at"], name: "index_customer_vat_verifications_on_customer_id_and_created_at"
    t.index ["customer_id"], name: "index_customer_vat_verifications_on_customer_id"
    t.index ["customer_id"], name: "index_cvv_pending_notification_on_customer_id", where: "notified_at IS NULL"
    t.index ["performed_by_user_id"], name: "index_customer_vat_verifications_on_performed_by_user_id"
  end

  create_table "customers", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.text "address"
    t.string "country_iso2", limit: 2, null: false
    t.datetime "created_at", null: false
    t.string "invoice_email_auto_contact_mode", default: "replace_contacts", null: false
    t.boolean "invoice_email_auto_enabled", default: false, null: false
    t.string "invoice_email_auto_subject_template", default: "", null: false
    t.string "invoice_email_auto_to", default: "", null: false
    t.integer "language_id", null: false
    t.string "matchcode", null: false
    t.text "name"
    t.text "notes"
    t.integer "payment_terms_days", default: 30, null: false
    t.integer "sales_tax_customer_class_id"
    t.text "supplier_number"
    t.integer "team_id", null: false
    t.datetime "updated_at", null: false
    t.text "vat_id"
    t.datetime "vat_id_verified_at"
    t.index "LOWER(matchcode)", name: "index_customers_on_lower_matchcode", unique: true
    t.index ["language_id"], name: "index_customers_on_language_id"
    t.index ["name"], name: "index_customers_on_name"
    t.index ["team_id"], name: "index_customers_on_team_id"
  end

  create_table "delivery_note_lines", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "delivery_note_id", null: false
    t.text "description"
    t.integer "position"
    t.decimal "quantity"
    t.text "title"
    t.text "type"
    t.datetime "updated_at", null: false
    t.index ["delivery_note_id"], name: "index_delivery_note_lines_on_delivery_note_id"
    t.index ["position"], name: "index_delivery_note_lines_on_position"
  end

  create_table "delivery_notes", force: :cascade do |t|
    t.integer "acceptance_attachment_id"
    t.string "acceptance_upload_token_digest"
    t.datetime "acceptance_upload_token_expires_at"
    t.datetime "acceptance_upload_token_minted_at"
    t.datetime "created_at", null: false
    t.string "cust_order"
    t.string "cust_reference"
    t.integer "customer_id", null: false
    t.date "date"
    t.date "delivery_end_date"
    t.date "delivery_start_date", null: false
    t.string "document_number"
    t.datetime "email_sent_at"
    t.text "internal_reference"
    t.integer "invoice_id"
    t.text "prelude"
    t.integer "project_id", null: false
    t.boolean "published", default: false, null: false
    t.datetime "updated_at", null: false
    t.index ["acceptance_attachment_id"], name: "index_delivery_notes_on_acceptance_attachment_id"
    t.index ["acceptance_upload_token_digest"], name: "index_delivery_notes_on_acceptance_upload_token_digest", unique: true
    t.index ["customer_id"], name: "index_delivery_notes_on_customer_id"
    t.index ["date"], name: "index_delivery_notes_on_date"
    t.index ["document_number"], name: "index_delivery_notes_on_document_number", unique: true
    t.index ["invoice_id"], name: "index_delivery_notes_on_invoice_id"
    t.index ["project_id"], name: "index_delivery_notes_on_project_id"
    t.index ["published"], name: "index_delivery_notes_on_published"
  end

  create_table "document_numbers", force: :cascade do |t|
    t.string "code"
    t.datetime "created_at", null: false
    t.string "format"
    t.date "last_date"
    t.string "last_number"
    t.integer "sequence"
    t.datetime "updated_at", null: false
  end

  create_table "group_memberships", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "group_id", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["group_id", "user_id"], name: "index_group_memberships_on_group_id_and_user_id", unique: true
    t.index ["group_id"], name: "index_group_memberships_on_group_id"
    t.index ["user_id"], name: "index_group_memberships_on_user_id"
  end

  create_table "group_permissions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "group_id", null: false
    t.string "permission", null: false
    t.datetime "updated_at", null: false
    t.index ["group_id", "permission"], name: "index_group_permissions_on_group_id_and_permission", unique: true
    t.index ["group_id"], name: "index_group_permissions_on_group_id"
  end

  create_table "groups", force: :cascade do |t|
    t.boolean "builtin", default: false, null: false
    t.boolean "bypass_team_scoping", default: false, null: false
    t.datetime "created_at", null: false
    t.string "description"
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_groups_on_name", unique: true
  end

  create_table "invoice_lines", force: :cascade do |t|
    t.decimal "amount"
    t.datetime "created_at", null: false
    t.text "description"
    t.integer "invoice_id"
    t.integer "position"
    t.decimal "quantity"
    t.decimal "rate"
    t.text "sales_tax_indicator_code"
    t.text "sales_tax_name"
    t.integer "sales_tax_product_class_id"
    t.decimal "sales_tax_rate"
    t.text "title"
    t.text "type"
    t.datetime "updated_at", null: false
  end

  create_table "invoice_tax_classes", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "indicator_code"
    t.integer "invoice_id"
    t.string "name"
    t.decimal "net"
    t.decimal "rate"
    t.integer "sales_tax_product_class_id"
    t.decimal "total"
    t.datetime "updated_at", null: false
    t.decimal "value"
    t.index ["invoice_id", "sales_tax_product_class_id"], name: "index_invoice_tax_classes_on_invoice_and_product_class", unique: true
  end

  create_table "invoices", force: :cascade do |t|
    t.integer "attachment_id"
    t.datetime "created_at", null: false
    t.string "cust_order"
    t.string "cust_reference"
    t.text "customer_account_number"
    t.text "customer_address"
    t.string "customer_country_iso2", limit: 2, null: false
    t.integer "customer_id", null: false
    t.text "customer_name"
    t.text "customer_supplier_number"
    t.text "customer_vat_id"
    t.date "date"
    t.string "document_number"
    t.date "due_date"
    t.datetime "email_sent_at"
    t.text "internal_reference"
    t.date "paid_at"
    t.integer "payment_terms_days", default: 30, null: false
    t.text "prelude"
    t.integer "project_id", null: false
    t.boolean "published", default: false, null: false
    t.decimal "sum_net", default: "0.0", null: false
    t.decimal "sum_total", default: "0.0", null: false
    t.text "tax_note"
    t.string "token"
    t.datetime "updated_at", null: false
    t.index ["date"], name: "index_invoices_on_date"
    t.index ["document_number"], name: "index_invoices_on_document_number", unique: true
    t.index ["paid_at"], name: "index_invoices_on_paid_at"
    t.index ["published", "date"], name: "index_invoices_on_published_and_date"
    t.index ["published"], name: "index_invoices_on_published"
  end

  create_table "issuer_companies", force: :cascade do |t|
    t.boolean "active"
    t.string "address"
    t.string "bankaccount_bank"
    t.string "bankaccount_bic"
    t.string "bankaccount_number"
    t.string "country_iso2", limit: 2, null: false
    t.datetime "created_at", null: false
    t.string "currency", default: "EUR", null: false
    t.string "document_accent_color"
    t.string "document_contact_line1"
    t.string "document_contact_line2"
    t.string "document_email_auto_bcc", default: "bcc@example.com", null: false
    t.string "document_email_from", default: "from@example.com", null: false
    t.string "document_email_reply_to"
    t.string "invoice_footer"
    t.string "legal_name"
    t.integer "money_decimal_places", default: 2, null: false
    t.binary "pdf_logo"
    t.string "pdf_logo_height"
    t.string "pdf_logo_width"
    t.binary "png_logo"
    t.string "reporting_email", default: "bcc@example.com", null: false
    t.string "short_name"
    t.datetime "updated_at", null: false
    t.string "vat_id"
    t.integer "vat_id_recheck_days", default: 90, null: false
    t.string "website_url"
    t.index ["active"], name: "index_issuer_companies_on_active", unique: true
  end

  create_table "languages", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "iso_code", limit: 2, null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["iso_code"], name: "index_languages_on_iso_code", unique: true
  end

  create_table "products", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.decimal "rate"
    t.integer "sales_tax_product_class_id"
    t.string "title"
    t.datetime "updated_at", null: false
    t.index ["title"], name: "index_products_on_title"
  end

  create_table "projects", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.integer "bill_to_customer_id"
    t.datetime "created_at", null: false
    t.string "department"
    t.text "description"
    t.string "matchcode", null: false
    t.integer "team_id", null: false
    t.datetime "updated_at", null: false
    t.index "LOWER(matchcode)", name: "index_projects_on_lower_matchcode", unique: true
    t.index ["team_id"], name: "index_projects_on_team_id"
  end

  create_table "sales_tax_customer_classes", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "invoice_note"
    t.string "name"
    t.datetime "updated_at", null: false
    t.boolean "vat_id_required", default: true, null: false
  end

  create_table "sales_tax_product_classes", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "indicator_code"
    t.boolean "is_default", default: false, null: false
    t.string "name"
    t.datetime "updated_at", null: false
    t.index ["is_default"], name: "index_sales_tax_product_classes_on_is_default", unique: true, where: "is_default = true"
  end

  create_table "sales_tax_rates", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.decimal "rate"
    t.integer "sales_tax_customer_class_id"
    t.integer "sales_tax_product_class_id"
    t.datetime "updated_at", null: false
  end

  create_table "team_memberships", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "team_id", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["team_id", "user_id"], name: "index_team_memberships_on_team_id_and_user_id", unique: true
    t.index ["team_id"], name: "index_team_memberships_on_team_id"
    t.index ["user_id"], name: "index_team_memberships_on_user_id"
  end

  create_table "teams", force: :cascade do |t|
    t.boolean "builtin", default: false, null: false
    t.datetime "created_at", null: false
    t.boolean "default", default: false, null: false
    t.string "description"
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["default"], name: "index_teams_unique_default", unique: true, where: "\"default\""
    t.index ["name"], name: "index_teams_on_name", unique: true
  end

  create_table "user_audit_events", force: :cascade do |t|
    t.string "action", null: false
    t.integer "actor_user_id"
    t.datetime "created_at", null: false
    t.string "ip_address"
    t.text "metadata"
    t.string "user_agent"
    t.integer "user_id"
    t.index ["action"], name: "index_user_audit_events_on_action"
    t.index ["actor_user_id", "created_at"], name: "index_user_audit_events_on_actor_user_id_and_created_at"
    t.index ["actor_user_id"], name: "index_user_audit_events_on_actor_user_id"
    t.index ["user_id", "created_at"], name: "index_user_audit_events_on_user_id_and_created_at"
    t.index ["user_id"], name: "index_user_audit_events_on_user_id"
  end

  create_table "user_credentials", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "external_id", null: false
    t.datetime "last_used_at"
    t.string "nickname", null: false
    t.text "public_key", null: false
    t.integer "sign_count", default: 0, null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["external_id"], name: "index_user_credentials_on_external_id", unique: true
    t.index ["user_id"], name: "index_user_credentials_on_user_id"
  end

  create_table "user_emails", force: :cascade do |t|
    t.string "address", null: false
    t.datetime "confirmation_expires_at"
    t.string "confirmation_token_digest"
    t.datetime "confirmed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["address"], name: "index_user_emails_on_address", unique: true
    t.index ["confirmation_token_digest"], name: "index_user_emails_on_confirmation_token_digest", unique: true, where: "confirmation_token_digest IS NOT NULL"
    t.index ["user_id"], name: "index_user_emails_on_user_id"
  end

  create_table "user_invites", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "created_by_user_id"
    t.datetime "expires_at", null: false
    t.string "purpose", null: false
    t.integer "target_user_id"
    t.string "token_digest", null: false
    t.datetime "updated_at", null: false
    t.datetime "used_at"
    t.integer "used_by_user_id"
    t.index ["created_by_user_id"], name: "index_user_invites_on_created_by_user_id"
    t.index ["expires_at"], name: "index_user_invites_on_expires_at"
    t.index ["target_user_id"], name: "index_user_invites_on_target_user_id"
    t.index ["token_digest"], name: "index_user_invites_on_token_digest", unique: true
    t.index ["used_by_user_id"], name: "index_user_invites_on_used_by_user_id"
  end

  create_table "user_sessions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "ip_address"
    t.datetime "last_seen_at", null: false
    t.datetime "terminated_at"
    t.integer "terminated_by_user_id"
    t.string "termination_reason"
    t.string "token_digest", null: false
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.integer "user_id", null: false
    t.index ["terminated_by_user_id"], name: "index_user_sessions_on_terminated_by_user_id"
    t.index ["token_digest"], name: "index_user_sessions_on_token_digest", unique: true
    t.index ["user_id", "terminated_at"], name: "index_user_sessions_on_user_id_and_terminated_at"
    t.index ["user_id"], name: "index_user_sessions_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "blocked_at"
    t.integer "blocked_by_user_id"
    t.string "blocked_reason"
    t.datetime "created_at", null: false
    t.string "full_name", null: false
    t.datetime "updated_at", null: false
    t.string "username", null: false
    t.string "webauthn_id", null: false
    t.index ["blocked_at"], name: "index_users_on_blocked_at"
    t.index ["blocked_by_user_id"], name: "index_users_on_blocked_by_user_id"
    t.index ["username"], name: "index_users_on_username", unique: true
  end

  add_foreign_key "acceptance_submissions", "attachments", on_delete: :nullify
  add_foreign_key "acceptance_submissions", "delivery_notes"
  add_foreign_key "acceptance_submissions", "users", column: "reviewed_by_id"
  add_foreign_key "customer_contact_projects", "customer_contacts"
  add_foreign_key "customer_contact_projects", "projects"
  add_foreign_key "customer_contacts", "customers"
  add_foreign_key "customer_vat_verifications", "customers"
  add_foreign_key "customer_vat_verifications", "users", column: "performed_by_user_id"
  add_foreign_key "customers", "languages"
  add_foreign_key "customers", "teams"
  add_foreign_key "delivery_note_lines", "delivery_notes"
  add_foreign_key "delivery_notes", "attachments", column: "acceptance_attachment_id"
  add_foreign_key "delivery_notes", "customers"
  add_foreign_key "delivery_notes", "invoices"
  add_foreign_key "delivery_notes", "projects"
  add_foreign_key "group_memberships", "groups"
  add_foreign_key "group_memberships", "users"
  add_foreign_key "group_permissions", "groups"
  add_foreign_key "invoices", "customers"
  add_foreign_key "invoices", "projects"
  add_foreign_key "projects", "teams"
  add_foreign_key "team_memberships", "teams"
  add_foreign_key "team_memberships", "users"
  add_foreign_key "user_audit_events", "users", column: "actor_user_id", on_delete: :nullify
  add_foreign_key "user_audit_events", "users", on_delete: :nullify
  add_foreign_key "user_credentials", "users"
  add_foreign_key "user_emails", "users"
  add_foreign_key "user_invites", "users", column: "created_by_user_id"
  add_foreign_key "user_invites", "users", column: "target_user_id"
  add_foreign_key "user_invites", "users", column: "used_by_user_id"
  add_foreign_key "user_sessions", "users"
  add_foreign_key "user_sessions", "users", column: "terminated_by_user_id"
  add_foreign_key "users", "users", column: "blocked_by_user_id"
end
