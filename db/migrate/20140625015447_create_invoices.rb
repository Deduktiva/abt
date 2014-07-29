class CreateInvoices < ActiveRecord::Migration
  def change
    create_table :invoices do |t|
      t.string :document_number
      t.boolean :published
      t.integer :customer_id
      t.integer :attachment_id
      t.integer :project_id
      t.date :date
      t.string :cust_reference
      t.string :cust_order
      t.text :prelude

      t.timestamps
    end
    add_index :invoices, :document_number, :unique => true
  end
end
