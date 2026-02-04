class CreateCustomerContacts < ActiveRecord::Migration[8.0]
  def change
    create_table :customer_contacts do |t|
      t.references :customer, null: false, foreign_key: true
      t.string :name, null: false
      t.string :email, null: false
      t.boolean :receives_invoices, default: false, null: false

      t.timestamps
    end

    # Junction table for customer_contacts and projects (many-to-many)
    create_table :customer_contact_projects do |t|
      t.references :customer_contact, null: false, foreign_key: true
      t.references :project, null: false, foreign_key: true

      t.timestamps
    end

    # Add unique constraint to prevent duplicates
    add_index :customer_contact_projects, [:customer_contact_id, :project_id],
              unique: true, name: 'index_customer_contact_projects_unique'
  end
end
