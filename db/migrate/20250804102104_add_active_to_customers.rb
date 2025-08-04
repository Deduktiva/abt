class AddActiveToCustomers < ActiveRecord::Migration[8.0]
  def change
    add_column :customers, :active, :boolean, default: true, null: false

    # Set all existing customers to active
    execute "UPDATE customers SET active = true"
  end
end
