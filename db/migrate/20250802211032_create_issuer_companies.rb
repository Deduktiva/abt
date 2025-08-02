class CreateIssuerCompanies < ActiveRecord::Migration[7.1]
  def change
    create_table :issuer_companies do |t|
      t.boolean :active
      t.string :short_name
      t.string :legal_name
      t.string :vat_id
      t.string :address
      t.string :bankaccount_bank
      t.string :bankaccount_bic
      t.string :bankaccount_number
      t.string :document_contact_line1
      t.string :document_contact_line2
      t.string :document_accent_color
      t.string :invoice_footer

      t.timestamps
    end

    # Quite the hack, but should be fine for now.
    add_index :issuer_companies, :active, :unique => true
  end
end
