class RemoveEmailFromCustomers < ActiveRecord::Migration[8.1]
  def change
    remove_column :customers, :email, :string
  end
end
