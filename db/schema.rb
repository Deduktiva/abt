# encoding: UTF-8
# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 20140730231925) do

  create_table "attachments", force: true do |t|
    t.string   "title"
    t.string   "filename"
    t.string   "content_type"
    t.binary   "data"
    t.datetime "created_at",   null: false
    t.datetime "updated_at",   null: false
  end

  create_table "customers", force: true do |t|
    t.string   "matchcode"
    t.text     "name"
    t.text     "address"
    t.integer  "time_budget"
    t.text     "notes"
    t.datetime "created_at",                  null: false
    t.datetime "updated_at",                  null: false
    t.integer  "sales_tax_customer_class_id"
    t.text     "vat_id"
    t.text     "supplier_number"
  end

  create_table "document_numbers", force: true do |t|
    t.string   "code"
    t.string   "format"
    t.integer  "sequence"
    t.string   "last_number"
    t.date     "last_date"
    t.datetime "created_at",  null: false
    t.datetime "updated_at",  null: false
  end

  create_table "invoice_lines", force: true do |t|
    t.integer  "invoice_id"
    t.text     "type"
    t.text     "title"
    t.text     "description"
    t.integer  "sales_tax_product_class_id"
    t.text     "sales_tax_name"
    t.text     "sales_tax_indicator_code"
    t.integer  "sales_tax_rate"
    t.float    "quantity"
    t.float    "rate"
    t.float    "amount"
    t.datetime "created_at",                 null: false
    t.datetime "updated_at",                 null: false
  end

  create_table "invoice_tax_classes", force: true do |t|
    t.integer  "invoice_id"
    t.integer  "sales_tax_product_class_id"
    t.string   "name"
    t.string   "indicator_code"
    t.decimal  "rate"
    t.decimal  "net"
    t.decimal  "value"
    t.decimal  "total"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "invoices", force: true do |t|
    t.string   "document_number"
    t.boolean  "published"
    t.integer  "customer_id"
    t.integer  "attachment_id"
    t.integer  "project_id"
    t.date     "date"
    t.string   "cust_reference"
    t.string   "cust_order"
    t.text     "prelude"
    t.datetime "created_at",               null: false
    t.datetime "updated_at",               null: false
    t.text     "customer_name"
    t.text     "customer_address"
    t.text     "customer_account_number"
    t.text     "customer_vat_id"
    t.text     "customer_supplier_number"
    t.date     "due_date"
    t.decimal  "sum_net"
    t.decimal  "sum_total"
  end

  add_index "invoices", ["document_number"], name: "index_invoices_on_document_number", unique: true

  create_table "products", force: true do |t|
    t.string   "title"
    t.text     "description"
    t.decimal  "rate"
    t.integer  "sales_tax_product_class_id"
    t.datetime "created_at",                 null: false
    t.datetime "updated_at",                 null: false
  end

  create_table "projects", force: true do |t|
    t.string   "matchcode"
    t.text     "description"
    t.integer  "time_budget"
    t.integer  "bill_to_customer_id"
    t.datetime "created_at",          null: false
    t.datetime "updated_at",          null: false
  end

  create_table "sales_tax_customer_classes", force: true do |t|
    t.string   "name"
    t.text     "invoice_note"
    t.datetime "created_at",   null: false
    t.datetime "updated_at",   null: false
  end

  create_table "sales_tax_product_classes", force: true do |t|
    t.string   "name"
    t.string   "indicator_code"
    t.datetime "created_at",     null: false
    t.datetime "updated_at",     null: false
  end

  create_table "sales_tax_rates", force: true do |t|
    t.integer  "sales_tax_customer_class_id"
    t.integer  "sales_tax_product_class_id"
    t.float    "rate"
    t.datetime "created_at",                  null: false
    t.datetime "updated_at",                  null: false
  end

end
