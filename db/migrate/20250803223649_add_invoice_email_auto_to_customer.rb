class AddInvoiceEmailAutoToCustomer < ActiveRecord::Migration[7.1]
  def change
    add_column :customers, :invoice_email_auto_to, :string, default: '', null: false
    add_column :customers, :invoice_email_auto_subject_template, :string, default: '', null: false
    add_column :customers, :invoice_email_auto_enabled, :boolean, default: false, null: false
  end
end
