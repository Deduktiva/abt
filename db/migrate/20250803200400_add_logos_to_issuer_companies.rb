class AddLogosToIssuerCompanies < ActiveRecord::Migration[7.1]
  def change
    add_column :issuer_companies, :pdf_logo, :binary
    add_column :issuer_companies, :pdf_logo_width, :string
    add_column :issuer_companies, :pdf_logo_height, :string
    add_column :issuer_companies, :png_logo, :binary
  end
end
