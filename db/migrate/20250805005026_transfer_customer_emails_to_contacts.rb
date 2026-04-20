class TransferCustomerEmailsToContacts < ActiveRecord::Migration[8.0]
  def up
    # Transfer existing customer email addresses to customer contacts
    Customer.where.not(email: [nil, '']).find_each do |customer|
      # Create a customer contact for the existing email
      CustomerContact.create!(
        customer: customer,
        name: "#{customer.name} (Main Contact)",
        email: customer.email,
        receives_invoices: true
      )
    end

    # Remove the email column from customers table
    remove_column :customers, :email
  end

  def down
    # Add the email column back
    add_column :customers, :email, :string

    # Transfer customer contact emails back to customers
    # (Note: This will only transfer the first contact's email)
    Customer.joins(:customer_contacts)
            .where(customer_contacts: { receives_invoices: true })
            .find_each do |customer|
      first_contact = customer.customer_contacts.where(receives_invoices: true).first
      customer.update_column(:email, first_contact.email) if first_contact
    end

    # Remove customer contacts (optional - might want to keep them)
    # CustomerContact.destroy_all
  end
end
