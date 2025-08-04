class AddEmailSentAtToInvoices < ActiveRecord::Migration[8.0]
  def change
    add_column :invoices, :email_sent_at, :datetime

    # Mark all previously published invoices as sent (assume they were sent when published)
    # Only mark invoices where the customer has an email address
    reversible do |dir|
      dir.up do
        execute <<-SQL
          UPDATE invoices
          SET email_sent_at = updated_at
          WHERE published = true
            AND email_sent_at IS NULL
            AND customer_id IN (
              SELECT id FROM customers
              WHERE (email IS NOT NULL AND email != '')
                 OR invoice_email_auto_enabled = true
            )
        SQL
      end
    end
  end
end
