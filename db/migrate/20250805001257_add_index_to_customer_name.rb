class AddIndexToCustomerName < ActiveRecord::Migration[8.0]
  def change
    add_index :customers, :name
  end
end
