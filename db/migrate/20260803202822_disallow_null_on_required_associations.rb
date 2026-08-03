class DisallowNullOnRequiredAssociations < ActiveRecord::Migration[8.1]
  # These columns back required `belongs_to` associations, but the database
  # accepted NULL — so a foreign key alone still let orphans through, the same
  # gap DisallowNullInvoiceIdOnInvoiceTaxClasses closed for invoice_tax_classes.
  # invoice_lines.invoice_id is the one that matters most: the mirror column
  # delivery_note_lines.delivery_note_id has been NOT NULL all along.
  #
  # If this fails, the table still holds rows with NULL in these columns —
  # inspect and resolve them before re-running.
  def change
    change_column_null :invoice_lines, :invoice_id, false
    change_column_null :customers, :sales_tax_customer_class_id, false
    change_column_null :products, :sales_tax_product_class_id, false
    change_column_null :sales_tax_rates, :sales_tax_customer_class_id, false
    change_column_null :sales_tax_rates, :sales_tax_product_class_id, false
  end
end
