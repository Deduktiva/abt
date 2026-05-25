class AddReceivesOfferEmailsToCustomerContacts < ActiveRecord::Migration[8.0]
  def change
    add_column :customer_contacts, :receives_offer_emails, :boolean, default: false, null: false
  end
end
