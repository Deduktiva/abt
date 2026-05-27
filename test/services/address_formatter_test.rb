require "test_helper"

class AddressFormatterTest < ActiveSupport::TestCase
  test "country_name returns the translation for a supported locale" do
    assert_equal "Österreich", AddressFormatter.country_name("AT", locale: :de)
  end

  test "country_name falls back to English for an unsupported locale" do
    assert_equal "Austria", AddressFormatter.country_name("AT", locale: :xx)
  end

  test "country_name returns nil for an unknown country code" do
    assert_nil AddressFormatter.country_name("XX", locale: :en)
  end

  test "build appends the localized country line when sides differ" do
    result = AddressFormatter.build(
      name: "Foo GmbH",
      address: "Hauptstraße 1\n1010 Wien",
      self_country: "AT",
      other_country: "DE",
      locale: :de
    )
    assert_equal "Foo GmbH\nHauptstraße 1\n1010 Wien\nÖsterreich", result
  end

  test "build omits the country line when self country is unknown" do
    result = AddressFormatter.build(
      name: "Foo",
      address: "Bar",
      self_country: AddressFormatter::UNKNOWN_COUNTRY,
      other_country: "DE",
      locale: :en
    )
    assert_equal "Foo\nBar", result
  end
end
