class CreateCustomerContacts < ActiveRecord::Migration[8.1]
  def change
    create_table :customer_contacts do |t|
      t.references :customer, null: false, foreign_key: true, index: true
      t.string :name, null: false
      t.string :email, null: false
      t.boolean :receives_invoice_emails, null: false, default: false
      t.boolean :receives_delivery_note_emails, null: false, default: false
      t.timestamps
    end

    create_table :customer_contact_projects do |t|
      t.references :customer_contact, null: false, foreign_key: true
      t.references :project, null: false, foreign_key: true
    end
    add_index :customer_contact_projects, [ :customer_contact_id, :project_id ], unique: true, name: :index_customer_contact_projects_uniq
  end
end
