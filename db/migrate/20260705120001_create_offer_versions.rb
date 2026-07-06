class CreateOfferVersions < ActiveRecord::Migration[8.1]
  def change
    create_table :offer_versions do |t|
      t.references :offer, null: false, foreign_key: true
      t.integer :version_number, null: false
      t.string :subject
      t.string :salutation_override
      t.date :delivery_date
      t.date :date
      t.references :sales_tax_product_class, foreign_key: true
      t.decimal :sum_net, default: "0.0"
      t.datetime :sent_at
      t.text :customer_name
      t.text :customer_address
      t.string :customer_country_iso2, limit: 2
      t.text :customer_supplier_number
      t.integer :payment_terms_days
      t.references :attachment, foreign_key: true
      t.timestamps
    end
    add_index :offer_versions, [ :offer_id, :version_number ], unique: true
    add_index :offer_versions, :offer_id, unique: true, where: "sent_at IS NULL",
              name: "index_offer_versions_one_draft_per_offer"

    add_foreign_key :offers, :offer_versions, column: :accepted_version_id
  end
end
