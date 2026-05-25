class CreateOffers < ActiveRecord::Migration[8.0]
  def change
    create_table :offers do |t|
      t.string :matchcode, null: false
      t.references :customer, null: false, foreign_key: true
      t.references :project, foreign_key: true
      t.references :addressed_to_contact, foreign_key: { to_table: :customer_contacts }
      t.string :document_number
      t.string :state, null: false, default: "draft"
      t.datetime :accepted_at
      t.integer :accepted_version_id
      t.datetime :rejected_at
      t.datetime :reopened_at
      t.datetime :expires_at
      t.datetime :reported_expired_at
      t.timestamps
    end
    add_index :offers, :document_number, unique: true
    add_index :offers, [ :customer_id, :matchcode ], unique: true, name: "index_offers_on_customer_id_and_matchcode_lower"

    create_table :offer_versions do |t|
      t.references :offer, null: false, foreign_key: true
      t.integer :version_number, null: false
      t.string :state, null: false, default: "draft"
      t.datetime :sent_at
      t.text :prelude
      t.string :salutation_override
      t.date :delivery_start_date
      t.date :delivery_end_date
      t.references :sales_tax_product_class, foreign_key: true
      t.integer :pdf_attachment_id
      t.string :client_line_override
      t.timestamps
    end
    add_index :offer_versions, [ :offer_id, :version_number ], unique: true
    add_foreign_key :offer_versions, :attachments, column: :pdf_attachment_id

    # Now that offer_versions exists, add the FK from offers.accepted_version_id.
    add_foreign_key :offers, :offer_versions, column: :accepted_version_id

    create_table :offer_milestones do |t|
      t.references :offer_version, null: false, foreign_key: true
      t.integer :position, null: false, default: 0
      t.string :title, null: false
      t.text :description
      t.string :trigger, null: false
      t.date :trigger_date
      t.decimal :net_amount, precision: 12, scale: 2, null: false
      # No column default: OfferMilestone#default_skip_delivery_note_from_trigger
      # derives this from `trigger` on create, and the before_validation hook
      # runs before the NOT NULL is enforced.
      t.boolean :skip_delivery_note, null: false
      t.integer :invoice_id
      t.integer :delivery_note_id
      t.timestamps
    end
    add_foreign_key :offer_milestones, :invoices, column: :invoice_id
    add_foreign_key :offer_milestones, :delivery_notes, column: :delivery_note_id
    # Partial unique indexes: each invoice / delivery_note can be linked from at
    # most one milestone. Allows multiple milestones to remain "not converted"
    # (invoice_id IS NULL).
    add_index :offer_milestones, :invoice_id, unique: true, where: "invoice_id IS NOT NULL"
    add_index :offer_milestones, :delivery_note_id, unique: true, where: "delivery_note_id IS NOT NULL"
  end
end
