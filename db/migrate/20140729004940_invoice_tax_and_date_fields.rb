class InvoiceTaxAndDateFields < ActiveRecord::Migration
  def change
    add_column :invoices, :due_date, :date
    add_column :invoices, :tax_classes, :text
    add_column :invoices, :sum_net, :decimal
    add_column :invoices, :sum_total, :decimal
  end
end
