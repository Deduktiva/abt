class AddSalesTaxCustomerClassIdToCustomers < ActiveRecord::Migration
  def change
    add_column :customers, :sales_tax_customer_class_id, :integer
  end
end
