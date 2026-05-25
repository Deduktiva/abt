class AddOfferColumnsToIssuerCompanies < ActiveRecord::Migration[8.0]
  def change
    change_table :issuer_companies, bulk: true do |t|
      t.integer :offer_validity_days, default: 30, null: false
      t.string :offer_footer
    end
  end
end
