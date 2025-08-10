class AddPaymentTrackingToInvoices < ActiveRecord::Migration[8.0]
  def change
    add_column :invoices, :paid_at, :datetime
    add_column :invoices, :payment_method, :string
    add_column :invoices, :payment_reference, :string
  end
end
