class AddInvoiceCustomerAndProjectForeignKeys < ActiveRecord::Migration[8.1]
  # invoices.customer_id / project_id were NOT NULL but had no FK, so the
  # before_destroy guards on Customer/Project were the only thing stopping a
  # delete — a check-then-delete race a concurrent invoice create can slip
  # through. The FKs make the database the source of truth (delivery_notes
  # already has the equivalent constraints).
  def change
    add_foreign_key :invoices, :customers
    add_foreign_key :invoices, :projects
  end
end
