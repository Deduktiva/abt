class InvoiceCustomerFields < ActiveRecord::Migration
  def change
    add_column :invoices, :customer_name, :text
    add_column :invoices, :customer_address, :text
    add_column :invoices, :customer_account_number, :text
    add_column :invoices, :customer_vat_id, :text
    add_column :invoices, :customer_supplier_number, :text
  end
end
