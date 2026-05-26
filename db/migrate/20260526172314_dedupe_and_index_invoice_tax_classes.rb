class DedupeAndIndexInvoiceTaxClasses < ActiveRecord::Migration[8.0]
  # Pre-fix, setup_tax_classes could create duplicate (invoice_id,
  # sales_tax_product_class_id) rows during the initial save of a draft
  # invoice. Remove any existing duplicates (keep the lowest id per group),
  # then enforce uniqueness so it can't recur.
  def up
    execute <<~SQL
      DELETE FROM invoice_tax_classes
      WHERE id NOT IN (
        SELECT MIN(id)
        FROM invoice_tax_classes
        GROUP BY invoice_id, sales_tax_product_class_id
      )
    SQL

    add_index :invoice_tax_classes,
              [ :invoice_id, :sales_tax_product_class_id ],
              unique: true,
              name: "index_invoice_tax_classes_on_invoice_and_product_class"
  end

  def down
    remove_index :invoice_tax_classes,
                 name: "index_invoice_tax_classes_on_invoice_and_product_class"
  end
end
