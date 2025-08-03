class AddCurrencyToIssuerCompanies < ActiveRecord::Migration[7.1]
  def change
    add_column :issuer_companies, :currency, :string, default: 'EUR', null: false
    
    # Update existing issuer companies to EUR
    reversible do |dir|
      dir.up do
        execute "UPDATE issuer_companies SET currency = 'EUR' WHERE currency IS NULL"
      end
    end
  end
end
