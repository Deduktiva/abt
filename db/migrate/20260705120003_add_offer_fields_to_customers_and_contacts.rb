class AddOfferFieldsToCustomersAndContacts < ActiveRecord::Migration[8.1]
  def change
    add_column :customers, :offer_validity_days, :integer
    add_column :customers, :offer_milestone_split_threshold, :decimal
    add_column :customers, :offer_milestone_templates_below, :text
    add_column :customers, :offer_milestone_templates_above, :text
    add_column :customer_contacts, :receives_offer_emails, :boolean, null: false, default: false
  end
end
