class CreateSalesTaxCustomerClasses < ActiveRecord::Migration[6.0]
  def change
    create_table :sales_tax_customer_classes do |t|
      t.string :name
      t.text :invoice_note

      t.timestamps
    end
  end
end
