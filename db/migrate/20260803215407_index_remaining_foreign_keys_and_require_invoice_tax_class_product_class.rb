class IndexRemainingForeignKeysAndRequireInvoiceTaxClassProductClass < ActiveRecord::Migration[8.1]
  # Two gaps the previous sweep left behind.
  #
  # invoices.customer_id, invoices.project_id and offers.accepted_version_id
  # are the last foreign keys without a covering index — invoices is the table
  # that grows without bound, and Customer#used_in_invoices? runs on every row
  # of the customers list.
  #
  # invoice_tax_classes.sales_tax_product_class_id backs a required
  # `belongs_to` but still accepted NULL, so the foreign key added alongside it
  # was satisfied by orphans. It also left the unique index on
  # (invoice_id, sales_tax_product_class_id) unable to dedupe in PostgreSQL,
  # where NULLs are all distinct — an invoice could accumulate any number of
  # NULL-class rows, each summed into sum_total.
  #
  # The NOT NULL will crash if such rows exist. What to do with them is the
  # operator's call:
  #
  #   SELECT * FROM invoice_tax_classes WHERE sales_tax_product_class_id IS NULL;
  def change
    add_index :invoices, :customer_id
    add_index :invoices, :project_id
    add_index :offers, :accepted_version_id

    change_column_null :invoice_tax_classes, :sales_tax_product_class_id, false
  end
end
