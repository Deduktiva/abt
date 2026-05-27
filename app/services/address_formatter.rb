class AddressFormatter
  # Sentinel written by the country backfill migrations when no country could
  # be inferred from existing address text. Not a valid ISO 3166-1 alpha-2
  # code — `valid_iso2?` rejects it, so the renderer and publish_problems
  # treat ZZ-rows the same as any other invalid country.
  UNKNOWN_COUNTRY = "ZZ"

  def self.build(name:, address:, self_country:, other_country:, locale:)
    lines = [ name, address ]
    lines << country_name(self_country, locale: locale) if self_country != other_country
    lines.compact.join("\n")
  end

  def self.valid_iso2?(code)
    ISO3166::Country.codes.include?(code)
  end

  def self.country_name(code, locale:)
    country = ISO3166::Country.new(code)
    country && (country.translation(locale.to_s) || country.iso_short_name)
  end
end
