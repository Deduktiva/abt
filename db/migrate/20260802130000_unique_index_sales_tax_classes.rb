class UniqueIndexSalesTaxClasses < ActiveRecord::Migration[8.0]
  # This will crash if the uniqueness is not satisfied.
  def up
    add_index :sales_tax_product_classes, :indicator_code, unique: true
    add_index :sales_tax_product_classes, :name, unique: true
    add_index :sales_tax_customer_classes, :name, unique: true
  end

  def down
    remove_index :sales_tax_product_classes, :indicator_code
    remove_index :sales_tax_product_classes, :name
    remove_index :sales_tax_customer_classes, :name
  end
end
