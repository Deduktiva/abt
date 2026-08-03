require "test_helper"

class CurrencyHelperTest < ActionView::TestCase
  test "currency_symbol maps each currency to its symbol, falling back to the raw code" do
    { "EUR" => "€", "USD" => "$", "GBP" => "£", "CHF" => "CHF" }.each do |currency, symbol|
      @current_currency = currency
      assert_equal symbol, currency_symbol
    end
  end

  test "format_currency prefixes the amount with the currency symbol" do
    @current_currency = "EUR"
    assert_equal "€60.00", format_currency(60)
  end

  test "format_currency returns blank for nil" do
    assert_equal "", format_currency(nil)
  end

  test "format_currency uses the issuer's money_decimal_places" do
    businesses(:one).update!(money_decimal_places: 3)
    assert_equal "€12.340", format_currency(12.34)
  end
end
