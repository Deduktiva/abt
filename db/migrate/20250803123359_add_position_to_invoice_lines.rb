class AddPositionToInvoiceLines < ActiveRecord::Migration[7.1]
  def change
    add_column :invoice_lines, :position, :integer

    # Set default positions for existing records
    reversible do |dir|
      dir.up do
        # Group by invoice and set positions based on current order (by id)
        execute <<-SQL
          UPDATE invoice_lines
          SET position = subquery.row_number
          FROM (
            SELECT id, ROW_NUMBER() OVER (PARTITION BY invoice_id ORDER BY id) as row_number
            FROM invoice_lines
          ) AS subquery
          WHERE invoice_lines.id = subquery.id
        SQL
      end
    end
  end
end
