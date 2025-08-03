class AddPaymentTermsDaysToCustomers < ActiveRecord::Migration[7.1]
  def change
    add_column :customers, :payment_terms_days, :integer, default: 30, null: false
    
    # Update existing customers to have 30 day payment terms
    reversible do |dir|
      dir.up do
        execute "UPDATE customers SET payment_terms_days = 30 WHERE payment_terms_days IS NULL"
      end
    end
  end
end
