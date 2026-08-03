class AddEmailQueuedAtToDocuments < ActiveRecord::Migration[8.1]
  def change
    add_column :invoices, :email_queued_at, :datetime
    add_column :delivery_notes, :email_queued_at, :datetime
  end
end
