class AddInvoiceEmailAutoContactModeToCustomers < ActiveRecord::Migration[8.1]
  def change
    add_column :customers, :invoice_email_auto_contact_mode, :string,
               null: false, default: "replace_contacts"
  end
end
