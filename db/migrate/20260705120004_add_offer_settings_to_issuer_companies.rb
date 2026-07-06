class AddOfferSettingsToIssuerCompanies < ActiveRecord::Migration[8.1]
  def change
    add_column :issuer_companies, :offer_validity_days, :integer, null: false, default: 30
    add_column :issuer_companies, :offer_footer, :string
  end
end
