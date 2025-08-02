class CustomerNumbers < ActiveRecord::Migration[6.0]
  def change
    add_column :customers, :vat_id, :text
    add_column :customers, :supplier_number, :text
  end
end
