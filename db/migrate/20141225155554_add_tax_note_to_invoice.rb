class AddTaxNoteToInvoice < ActiveRecord::Migration
  def change
    add_column :invoices, :tax_note, :text
  end
end
