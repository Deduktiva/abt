class RemovePreludeTextColumns < ActiveRecord::Migration[8.1]
  def up
    remove_column :invoices, :prelude
    remove_column :delivery_notes, :prelude
  end

  def down
    add_column :invoices, :prelude, :text
    add_column :delivery_notes, :prelude, :text
  end
end
