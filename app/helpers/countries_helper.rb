module CountriesHelper
  def country_options
    @country_options ||= ISO3166::Country.all
      .map { |c| [ c.iso_short_name, c.alpha2 ] }
      .sort_by { |name, _| name }
  end

  def country_name(code)
    AddressFormatter.country_name(code, locale: I18n.locale)
  end

  def country_unknown?(code)
    !AddressFormatter.valid_iso2?(code)
  end
end
