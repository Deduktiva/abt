class AddIsDefaultToSalesTaxProductClasses < ActiveRecord::Migration[8.0]
  def change
    add_column :sales_tax_product_classes, :is_default, :boolean, default: false, null: false
    add_index :sales_tax_product_classes, :is_default, unique: true, where: "is_default = true"
  end
end
