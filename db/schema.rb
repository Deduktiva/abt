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
# It's strongly recommended to check this file into your version control system.

ActiveRecord::Schema.define(:version => 20140625013236) do

  create_table "attachments", :force => true do |t|
    t.string   "title"
    t.string   "filename"
    t.string   "content_type"
    t.binary   "data"
    t.datetime "created_at",   :null => false
    t.datetime "updated_at",   :null => false
  end

  create_table "customers", :force => true do |t|
    t.string   "matchcode"
    t.text     "name"
    t.text     "address"
    t.integer  "time_budget"
    t.text     "notes"
    t.datetime "created_at",                  :null => false
    t.datetime "updated_at",                  :null => false
    t.integer  "sales_tax_customer_class_id"
  end

  create_table "projects", :force => true do |t|
    t.string   "matchcode"
    t.text     "description"
    t.integer  "time_budget"
    t.integer  "bill_to_customer_id"
    t.datetime "created_at",          :null => false
    t.datetime "updated_at",          :null => false
  end

  create_table "sales_tax_customer_classes", :force => true do |t|
    t.string   "name"
    t.text     "invoice_note"
    t.datetime "created_at",   :null => false
    t.datetime "updated_at",   :null => false
  end

  create_table "sales_tax_product_classes", :force => true do |t|
    t.string   "name"
    t.string   "indicator_code"
    t.datetime "created_at",     :null => false
    t.datetime "updated_at",     :null => false
  end

  create_table "sales_tax_rates", :force => true do |t|
    t.integer  "sales_tax_customer_class_id"
    t.integer  "sales_tax_product_class_id"
    t.float    "rate"
    t.datetime "created_at",                  :null => false
    t.datetime "updated_at",                  :null => false
  end

end
