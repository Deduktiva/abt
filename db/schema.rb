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

ActiveRecord::Schema[7.1].define(version: 2025_08_03_123359) do
  create_table "attachments", force: :cascade do |t|
    t.string "title"
    t.string "filename"
    t.string "content_type"
    t.binary "data"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "customers", force: :cascade do |t|
    t.string "matchcode"
    t.text "name"
    t.text "address"
    t.integer "time_budget"
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "sales_tax_customer_class_id"
    t.text "vat_id"
    t.text "supplier_number"
    t.string "email"
    t.integer "payment_terms_days", default: 30, null: false
  end

  create_table "document_numbers", force: :cascade do |t|
    t.string "code"
    t.string "format"
    t.integer "sequence"
    t.string "last_number"
    t.date "last_date"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "invoice_lines", force: :cascade do |t|
    t.integer "invoice_id"
    t.text "type"
    t.text "title"
    t.text "description"
    t.integer "sales_tax_product_class_id"
    t.text "sales_tax_name"
    t.text "sales_tax_indicator_code"
    t.integer "sales_tax_rate"
    t.float "quantity"
    t.float "rate"
    t.float "amount"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "position"
  end

  create_table "invoice_tax_classes", force: :cascade do |t|
    t.integer "invoice_id"
    t.integer "sales_tax_product_class_id"
    t.string "name"
    t.string "indicator_code"
    t.decimal "rate"
    t.decimal "net"
    t.decimal "value"
    t.decimal "total"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "invoices", force: :cascade do |t|
    t.string "document_number"
    t.boolean "published"
    t.integer "customer_id"
    t.integer "attachment_id"
    t.integer "project_id"
    t.date "date"
    t.string "cust_reference"
    t.string "cust_order"
    t.text "prelude"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "customer_name"
    t.text "customer_address"
    t.text "customer_account_number"
    t.text "customer_vat_id"
    t.text "customer_supplier_number"
    t.date "due_date"
    t.decimal "sum_net"
    t.decimal "sum_total"
    t.string "token"
    t.text "tax_note"
    t.index ["document_number"], name: "index_invoices_on_document_number", unique: true
  end

  create_table "issuer_companies", force: :cascade do |t|
    t.boolean "active"
    t.string "short_name"
    t.string "legal_name"
    t.string "vat_id"
    t.string "address"
    t.string "bankaccount_bank"
    t.string "bankaccount_bic"
    t.string "bankaccount_number"
    t.string "document_contact_line1"
    t.string "document_contact_line2"
    t.string "document_accent_color"
    t.string "invoice_footer"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "currency", default: "EUR", null: false
    t.index ["active"], name: "index_issuer_companies_on_active", unique: true
  end

  create_table "products", force: :cascade do |t|
    t.string "title"
    t.text "description"
    t.decimal "rate"
    t.integer "sales_tax_product_class_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "projects", force: :cascade do |t|
    t.string "matchcode"
    t.text "description"
    t.integer "time_budget"
    t.integer "bill_to_customer_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "sales_tax_customer_classes", force: :cascade do |t|
    t.string "name"
    t.text "invoice_note"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "sales_tax_product_classes", force: :cascade do |t|
    t.string "name"
    t.string "indicator_code"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "sales_tax_rates", force: :cascade do |t|
    t.integer "sales_tax_customer_class_id"
    t.integer "sales_tax_product_class_id"
    t.decimal "rate"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

end
