class CreateProducts < ActiveRecord::Migration[6.0]
  def change
    create_table :products do |t|
      t.string :title
      t.text :description
      t.decimal :rate
      t.integer :sales_tax_product_class_id

      t.timestamps
    end
  end
end
