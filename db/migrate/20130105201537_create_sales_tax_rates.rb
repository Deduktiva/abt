class CreateSalesTaxRates < ActiveRecord::Migration
  def change
    create_table :sales_tax_rates do |t|
      t.integer :sales_tax_customer_class_id
      t.integer :sales_tax_product_class_id
      t.float :rate

      t.timestamps
    end
  end
end
