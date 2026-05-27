class AddNotifiedAtToCustomerVatVerifications < ActiveRecord::Migration[8.1]
  def change
    add_column :customer_vat_verifications, :notified_at, :datetime

    # Partial index — the digest job only ever queries rows that have not yet
    # been included in a sent report. The table grows monotonically with every
    # daily VIES re-check across all customers; keeping the index narrow keeps
    # the daily query cheap forever.
    add_index :customer_vat_verifications, :customer_id,
              name: "index_cvv_pending_notification_on_customer_id",
              where: "notified_at IS NULL"
  end
end
