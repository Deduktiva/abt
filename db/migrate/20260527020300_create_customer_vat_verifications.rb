class CreateCustomerVatVerifications < ActiveRecord::Migration[8.1]
  def change
    create_table :customer_vat_verifications do |t|
      t.references :customer, null: false, foreign_key: true
      t.text :vat_id, null: false
      t.string :country_iso2, limit: 2
      t.boolean :valid_response
      t.text :request_identifier
      t.datetime :request_date
      t.text :trader_name
      t.text :trader_address
      t.text :raw_response
      t.text :error_code
      t.references :performed_by_user, foreign_key: { to_table: :users }
      t.timestamps
    end

    add_index :customer_vat_verifications, [ :customer_id, :created_at ]
  end
end
