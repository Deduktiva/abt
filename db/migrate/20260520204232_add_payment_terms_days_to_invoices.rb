class AddPaymentTermsDaysToInvoices < ActiveRecord::Migration[8.0]
  def up
    add_column :invoices, :payment_terms_days, :integer

    # Backfill values for existing invoices in Ruby so it works for both SQLite and PostgreSQL.
    say_with_time "Backfilling invoices.payment_terms_days" do
      conn = ActiveRecord::Base.connection
      rows = conn.exec_query(<<~SQL).rows
        SELECT invoices.id, invoices.date, invoices.due_date, customers.payment_terms_days
        FROM invoices
        LEFT JOIN customers ON customers.id = invoices.customer_id
      SQL

      rows.each do |id, date_val, due_date_val, customer_terms|
        date = date_val.is_a?(Date) ? date_val : (Date.parse(date_val.to_s) rescue nil)
        due_date = due_date_val.is_a?(Date) ? due_date_val : (Date.parse(due_date_val.to_s) rescue nil)

        terms = if date && due_date
                  (due_date - date).to_i
                else
                  customer_terms
                end
        terms ||= 30

        conn.exec_update(
          "UPDATE invoices SET payment_terms_days = #{conn.quote(terms)} WHERE id = #{conn.quote(id)}"
        )
      end
    end

    change_column_null :invoices, :payment_terms_days, false
    change_column_default :invoices, :payment_terms_days, 30
  end

  def down
    remove_column :invoices, :payment_terms_days
  end
end
