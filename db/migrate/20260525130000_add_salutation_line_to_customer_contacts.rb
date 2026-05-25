class AddSalutationLineToCustomerContacts < ActiveRecord::Migration[8.1]
  def change
    add_column :customer_contacts, :salutation_line, :string
  end
end
