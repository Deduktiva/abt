class DisallowNullInvoiceIdOnInvoiceTaxClasses < ActiveRecord::Migration[8.1]
  # The foreign key accepts NULL, so orphaned rows satisfied it. If this fails,
  # the table still holds orphans — inspect and remove them before re-running.
  def change
    change_column_null :invoice_tax_classes, :invoice_id, false
  end
end
