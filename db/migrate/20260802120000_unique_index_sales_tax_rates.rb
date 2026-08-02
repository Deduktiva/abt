class UniqueIndexSalesTaxRates < ActiveRecord::Migration[8.0]
  # This will crash if the uniqueness is not satisfied.
  def up
    add_index :sales_tax_rates,
              [ :sales_tax_customer_class_id, :sales_tax_product_class_id ],
              unique: true,
              name: "index_sales_tax_rates_on_customer_and_product_class"
  end

  def down
    remove_index :sales_tax_rates,
                 name: "index_sales_tax_rates_on_customer_and_product_class"
  end
end
