class AddCountryIso2ToIssuerCompaniesAndCustomers < ActiveRecord::Migration[8.1]
  UNKNOWN = "ZZ"

  class MigrationIssuerCompany < ActiveRecord::Base
    self.table_name = "issuer_companies"
  end

  class MigrationCustomer < ActiveRecord::Base
    self.table_name = "customers"
  end

  def up
    add_column :issuer_companies, :country_iso2, :string, limit: 2,
      comment: "ISO 3166-1 alpha-2 country code, or 'ZZ' (unknown) for rows that pre-date the structured country column"
    add_column :customers, :country_iso2, :string, limit: 2,
      comment: "ISO 3166-1 alpha-2 country code, or 'ZZ' (unknown) for rows that pre-date the structured country column"

    name_lookup = build_name_lookup

    [ MigrationIssuerCompany, MigrationCustomer ].each do |klass|
      klass.find_each do |row|
        code, stripped_address = detect_country(row.address, name_lookup)
        row.update_columns(
          country_iso2: code || UNKNOWN,
          address: code ? stripped_address : row.address
        )
      end
    end

    change_column_null :issuer_companies, :country_iso2, false
    change_column_null :customers, :country_iso2, false
  end

  def down
    remove_column :customers, :country_iso2
    remove_column :issuer_companies, :country_iso2
  end

  private

  def build_name_lookup
    require "countries"
    lookup = {}
    ISO3166::Country.all.each do |country|
      names = [ country.iso_short_name, country.common_name, *country.unofficial_names ].compact
      names.each { |n| lookup[n.downcase.strip] = country.alpha2 }
    end
    lookup
  end

  def detect_country(address, name_lookup)
    return [ nil, address ] if address.blank?
    lines = address.split(/\r?\n/)
    last = lines.last.to_s.strip
    return [ nil, address ] if last.empty?
    code = name_lookup[last.downcase]
    return [ nil, address ] unless code
    lines.pop
    [ code, lines.join("\n").rstrip ]
  end
end
