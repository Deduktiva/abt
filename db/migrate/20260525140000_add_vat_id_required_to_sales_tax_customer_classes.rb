class AddVatIdRequiredToSalesTaxCustomerClasses < ActiveRecord::Migration[8.0]
  def change
    add_column :sales_tax_customer_classes, :vat_id_required, :boolean, default: true, null: false
  end
end
