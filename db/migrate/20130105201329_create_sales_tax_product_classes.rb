class CreateSalesTaxProductClasses < ActiveRecord::Migration[6.0]
  def change
    create_table :sales_tax_product_classes do |t|
      t.string :name
      t.string :indicator_code

      t.timestamps
    end
  end
end
