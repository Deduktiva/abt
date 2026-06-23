class AddInternalReferenceToDocs < ActiveRecord::Migration[8.1]
  def change
    add_column :delivery_notes, :internal_reference, :text
    add_column :invoices, :internal_reference, :text
  end
end
