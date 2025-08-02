class AddTaxNoteToInvoice < ActiveRecord::Migration[6.0]
  def change
    add_column :invoices, :tax_note, :text
  end
end
