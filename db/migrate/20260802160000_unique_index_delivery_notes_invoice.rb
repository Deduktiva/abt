class UniqueIndexDeliveryNotesInvoice < ActiveRecord::Migration[8.0]
  # This will crash if the uniqueness is not satisfied.
  def up
    remove_index :delivery_notes, :invoice_id
    add_index :delivery_notes, :invoice_id, unique: true, where: "invoice_id IS NOT NULL"
  end

  def down
    remove_index :delivery_notes, :invoice_id
    add_index :delivery_notes, :invoice_id
  end
end
