class AddInvoiceIndexToInvoiceLines < ActiveRecord::Migration[8.1]
  def change
    add_index :invoice_lines, [ :invoice_id, :position ]
  end
end
