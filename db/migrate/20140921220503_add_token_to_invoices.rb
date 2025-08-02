class AddTokenToInvoices < ActiveRecord::Migration[6.0]
  def change
    add_column :invoices, :token, :string
  end
end
