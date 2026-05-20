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

ActiveRecord::Schema[8.1].define(version: 2025_08_10_173512) do
  create_table "attachments", force: :cascade do |t|
    t.string "content_type"
    t.datetime "created_at", null: false
    t.binary "data"
    t.string "filename"
    t.string "title"
    t.datetime "updated_at", null: false
  end

  create_table "customers", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.text "address"
    t.datetime "created_at", null: false
    t.string "email"
    t.boolean "invoice_email_auto_enabled", default: false, null: false
    t.string "invoice_email_auto_subject_template", default: "", null: false
    t.string "invoice_email_auto_to", default: "", null: false
    t.integer "language_id", null: false
    t.string "matchcode"
    t.text "name"
    t.text "notes"
    t.integer "payment_terms_days", default: 30, null: false
    t.integer "sales_tax_customer_class_id"
    t.text "supplier_number"
    t.datetime "updated_at", null: false
    t.text "vat_id"
    t.index ["language_id"], name: "index_customers_on_language_id"
    t.index ["name"], name: "index_customers_on_name"
  end

  create_table "delivery_note_lines", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "delivery_note_id", null: false
    t.text "description"
    t.integer "position"
    t.float "quantity"
    t.text "title"
    t.text "type"
    t.datetime "updated_at", null: false
    t.index ["delivery_note_id"], name: "index_delivery_note_lines_on_delivery_note_id"
    t.index ["position"], name: "index_delivery_note_lines_on_position"
  end

  create_table "delivery_notes", force: :cascade do |t|
    t.integer "acceptance_attachment_id"
    t.datetime "created_at", null: false
    t.string "cust_order"
    t.string "cust_reference"
    t.integer "customer_id", null: false
    t.date "date"
    t.date "delivery_end_date"
    t.date "delivery_start_date"
    t.string "document_number"
    t.datetime "email_sent_at"
    t.integer "invoice_id"
    t.text "prelude"
    t.integer "project_id", null: false
    t.boolean "published"
    t.datetime "updated_at", null: false
    t.index ["acceptance_attachment_id"], name: "index_delivery_notes_on_acceptance_attachment_id"
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

  create_table "invoice_lines", force: :cascade do |t|
    t.float "amount"
    t.datetime "created_at", null: false
    t.text "description"
    t.integer "invoice_id"
    t.integer "position"
    t.float "quantity"
    t.float "rate"
    t.text "sales_tax_indicator_code"
    t.text "sales_tax_name"
    t.integer "sales_tax_product_class_id"
    t.integer "sales_tax_rate"
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
  end

  create_table "invoices", force: :cascade do |t|
    t.integer "attachment_id"
    t.datetime "created_at", null: false
    t.string "cust_order"
    t.string "cust_reference"
    t.text "customer_account_number"
    t.text "customer_address"
    t.integer "customer_id"
    t.text "customer_name"
    t.text "customer_supplier_number"
    t.text "customer_vat_id"
    t.date "date"
    t.string "document_number"
    t.date "due_date"
    t.datetime "email_sent_at"
    t.text "prelude"
    t.integer "project_id"
    t.boolean "published"
    t.decimal "sum_net"
    t.decimal "sum_total"
    t.text "tax_note"
    t.string "token"
    t.datetime "updated_at", null: false
    t.index ["date"], name: "index_invoices_on_date"
    t.index ["document_number"], name: "index_invoices_on_document_number", unique: true
    t.index ["published", "date"], name: "index_invoices_on_published_and_date"
    t.index ["published"], name: "index_invoices_on_published"
  end

  create_table "issuer_companies", force: :cascade do |t|
    t.boolean "active"
    t.string "address"
    t.string "bankaccount_bank"
    t.string "bankaccount_bic"
    t.string "bankaccount_number"
    t.datetime "created_at", null: false
    t.string "currency", default: "EUR", null: false
    t.string "document_accent_color"
    t.string "document_contact_line1"
    t.string "document_contact_line2"
    t.string "document_email_auto_bcc", default: "bcc@example.com", null: false
    t.string "document_email_from", default: "from@example.com", null: false
    t.string "invoice_footer"
    t.string "legal_name"
    t.binary "pdf_logo"
    t.string "pdf_logo_height"
    t.string "pdf_logo_width"
    t.binary "png_logo"
    t.string "short_name"
    t.datetime "updated_at", null: false
    t.string "vat_id"
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
    t.text "description"
    t.string "matchcode"
    t.datetime "updated_at", null: false
    t.index ["matchcode"], name: "index_projects_on_matchcode"
  end

  create_table "sales_tax_customer_classes", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "invoice_note"
    t.string "name"
    t.datetime "updated_at", null: false
  end

  create_table "sales_tax_product_classes", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "indicator_code"
    t.string "name"
    t.datetime "updated_at", null: false
  end

  create_table "sales_tax_rates", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.decimal "rate"
    t.integer "sales_tax_customer_class_id"
    t.integer "sales_tax_product_class_id"
    t.datetime "updated_at", null: false
  end

  add_foreign_key "customers", "languages"
  add_foreign_key "delivery_note_lines", "delivery_notes"
  add_foreign_key "delivery_notes", "attachments", column: "acceptance_attachment_id"
  add_foreign_key "delivery_notes", "customers"
  add_foreign_key "delivery_notes", "invoices"
  add_foreign_key "delivery_notes", "projects"
end
