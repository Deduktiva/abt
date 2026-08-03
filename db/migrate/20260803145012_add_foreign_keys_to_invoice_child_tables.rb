class AddForeignKeysToInvoiceChildTables < ActiveRecord::Migration[8.1]
  # Invoice declared neither `dependent:` nor a foreign key for its lines and
  # tax classes, so every destroyed invoice left both behind. delivery_note_lines
  # has had the matching constraint all along; the invoice side was missed.
  #
  # This will crash if rows are already orphaned. What to do with them is the
  # operator's call, not something to decide silently here:
  #
  #   SELECT * FROM invoice_lines WHERE invoice_id NOT IN (SELECT id FROM invoices);
  #   SELECT * FROM invoice_tax_classes WHERE invoice_id NOT IN (SELECT id FROM invoices);
  def change
    add_foreign_key :invoice_lines, :invoices
    add_foreign_key :invoice_tax_classes, :invoices
  end
end
