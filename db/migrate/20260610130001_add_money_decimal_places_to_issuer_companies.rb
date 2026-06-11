class AddMoneyDecimalPlacesToIssuerCompanies < ActiveRecord::Migration[8.1]
  def change
    add_column :issuer_companies, :money_decimal_places, :integer, default: 2, null: false
  end
end
