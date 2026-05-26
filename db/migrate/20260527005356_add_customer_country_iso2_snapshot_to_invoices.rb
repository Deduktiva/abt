class AddCustomerCountryIso2SnapshotToInvoices < ActiveRecord::Migration[8.1]
  UNKNOWN = "ZZ"

  class MigrationInvoice < ActiveRecord::Base
    self.table_name = "invoices"
  end

  class MigrationCustomer < ActiveRecord::Base
    self.table_name = "customers"
  end

  def up
    add_column :invoices, :customer_country_iso2, :string, limit: 2,
      comment: "Snapshot of customer.country_iso2 at draft time; frozen on publish."

    customer_countries = MigrationCustomer.pluck(:id, :country_iso2).to_h
    name_lookup = build_name_lookup

    MigrationInvoice.find_each do |invoice|
      iso2 = customer_countries[invoice.customer_id] || UNKNOWN
      stripped = strip_country_line(invoice.customer_address, name_lookup)
      invoice.update_columns(
        customer_country_iso2: iso2,
        customer_address: stripped
      )
    end

    change_column_null :invoices, :customer_country_iso2, false
  end

  def down
    remove_column :invoices, :customer_country_iso2
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

  def strip_country_line(address, name_lookup)
    return address if address.blank?
    lines = address.split(/\r?\n/)
    last = lines.last.to_s.strip
    return address if last.empty?
    return address unless name_lookup[last.downcase]
    lines.pop
    lines.join("\n").rstrip
  end
end
