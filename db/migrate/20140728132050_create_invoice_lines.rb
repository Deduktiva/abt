class CreateInvoiceLines < ActiveRecord::Migration
  def change
    create_table :invoice_lines do |t|
      t.integer :invoice_id
      t.text :type
      t.text :title
      t.text :description
      t.integer :sales_tax_product_class_id
      t.text :sales_tax_name
      t.text :sales_tax_indicator_code
      t.integer :sales_tax_rate
      t.float :quantity
      t.float :rate
      t.float :amount

      t.timestamps
    end
  end
end
