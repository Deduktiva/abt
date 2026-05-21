class AddPaidAtToInvoices < ActiveRecord::Migration[8.0]
  def change
    add_column :invoices, :paid_at, :date
    add_index :invoices, :paid_at
  end
end
