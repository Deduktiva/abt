class AddIndexesToInvoicesForStatistics < ActiveRecord::Migration[8.0]
  def change
    add_index :invoices, :date
    add_index :invoices, :published
    add_index :invoices, [:published, :date]
  end
end
