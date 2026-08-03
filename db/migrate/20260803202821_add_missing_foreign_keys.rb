class AddMissingForeignKeys < ActiveRecord::Migration[8.1]
  # Every `belongs_to` in the app now has a matching database constraint. The
  # tax-class references were previously held together by before_destroy hooks
  # alone (SalesTaxProductClass#deletion_blocker says as much); projects
  # .bill_to_customer_id had no guard at all, so a customer used only as a
  # project's bill-to could be deleted out from under it.
  #
  # This will crash if rows already dangle. What to do with them is the
  # operator's call:
  #
  #   SELECT * FROM projects WHERE bill_to_customer_id IS NOT NULL
  #     AND bill_to_customer_id NOT IN (SELECT id FROM customers);
  #
  # ...and the equivalent for each other column below.
  def change
    # Indexes first: Postgres scans the referencing table on every parent
    # delete. sales_tax_rates.sales_tax_customer_class_id is skipped — it is
    # already the leading column of the composite unique index.
    add_index :customers, :sales_tax_customer_class_id
    add_index :products, :sales_tax_product_class_id
    add_index :sales_tax_rates, :sales_tax_product_class_id
    add_index :invoice_lines, :sales_tax_product_class_id
    add_index :invoice_tax_classes, :sales_tax_product_class_id
    add_index :invoices, :attachment_id
    add_index :projects, :bill_to_customer_id

    add_foreign_key :customers, :sales_tax_customer_classes
    add_foreign_key :products, :sales_tax_product_classes
    add_foreign_key :sales_tax_rates, :sales_tax_customer_classes
    add_foreign_key :sales_tax_rates, :sales_tax_product_classes
    add_foreign_key :invoice_lines, :sales_tax_product_classes
    add_foreign_key :invoice_tax_classes, :sales_tax_product_classes
    add_foreign_key :invoices, :attachments
    add_foreign_key :projects, :customers, column: :bill_to_customer_id
  end
end
