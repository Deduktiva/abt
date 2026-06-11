class MoneyColumnsToDecimal < ActiveRecord::Migration[8.1]
  # Money and quantity must be exact, not float. Columns are unbounded decimal
  # (like sum_net/net/value/total) so the configurable rounding precision
  # (IssuerCompany#money_decimal_places) is never truncated at the DB.
  def up
    change_column :invoice_lines, :rate,           :decimal
    change_column :invoice_lines, :quantity,       :decimal
    change_column :invoice_lines, :amount,         :decimal
    # Per-line tax-rate snapshot was integer, truncating fractional rates
    # (7.7 -> 7).
    change_column :invoice_lines, :sales_tax_rate, :decimal

    change_column :delivery_note_lines, :quantity, :decimal
  end

  def down
    change_column :delivery_note_lines, :quantity, :float

    change_column :invoice_lines, :sales_tax_rate, :integer
    change_column :invoice_lines, :amount,         :float
    change_column :invoice_lines, :quantity,       :float
    change_column :invoice_lines, :rate,           :float
  end
end
