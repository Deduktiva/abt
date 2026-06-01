class AddWebsiteUrlToIssuerCompanies < ActiveRecord::Migration[8.1]
  def up
    add_column :issuer_companies, :website_url, :string
  end

  def down
    remove_column :issuer_companies, :website_url
  end
end
