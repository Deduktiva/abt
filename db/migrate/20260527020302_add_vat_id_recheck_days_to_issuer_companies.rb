class AddVatIdRecheckDaysToIssuerCompanies < ActiveRecord::Migration[8.1]
  def change
    add_column :issuer_companies, :vat_id_recheck_days, :integer, null: false, default: 90
  end
end
