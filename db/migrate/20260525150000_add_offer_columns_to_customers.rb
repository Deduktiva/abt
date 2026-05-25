class AddOfferColumnsToCustomers < ActiveRecord::Migration[8.0]
  def change
    change_table :customers, bulk: true do |t|
      t.text :offer_boilerplate
      t.integer :offer_validity_days
      t.boolean :offer_email_auto_enabled, default: false, null: false
      t.string :offer_email_auto_subject_template, default: "", null: false
      t.string :offer_email_auto_to, default: "", null: false
      t.string :offer_email_auto_contact_mode, default: "replace_contacts", null: false
    end
  end
end
